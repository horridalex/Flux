package main

import (
	"net"
	"net/netip"
	"runtime"
	"sync"
	"sync/atomic"
	"time"

	"golang.org/x/net/icmp"
	"gvisor.dev/gvisor/pkg/tcpip"
	"gvisor.dev/gvisor/pkg/tcpip/checksum"
	"gvisor.dev/gvisor/pkg/tcpip/header"
)

// Ping goes through too, so a device can check the connection the usual way. gVisor never sees an
// echo request: stackTun hands it to handlePing, which sends it again from the iPhone with an
// unprivileged ICMP socket (iOS allows those without root), and the replies come back to the
// device with its own identifier. A reply only comes when the host really answers, unlike a stack
// that answers every ping itself. IPv4 only, like UDP, see udp.go.

const (
	// pingIdle closes a ping's socket once nothing went either way for this long.
	pingIdle = 10 * time.Second
	// maxPings caps the ICMP sockets. Each `ping` run is one, so this is plenty.
	maxPings = 64
)

// pingConn is the part of icmp.PacketConn a pinger uses, so tests can answer in memory.
type pingConn interface {
	WriteTo(b []byte, dst net.Addr) (int, error)
	ReadFrom(b []byte) (int, net.Addr, error)
	SetReadDeadline(t time.Time) error
	Close() error
}

func listenICMP() (pingConn, error) { return icmp.ListenPacket("udp4", "0.0.0.0") }

// pingKey is one `ping` run: who sends, to where, with which echo identifier.
type pingKey struct {
	device, dst netip.Addr
	id          uint16
}

// pinger is one ping run's iPhone socket, like a cone is one UDP port's.
type pinger struct {
	key   pingKey
	owner netip.Addr // whose traffic it is, see Server.owner
	// ourID is the identifier the iPhone sends with. On Darwin every ICMP socket sees every reply,
	// so it tells this run's apart. Linux picks its own and only shows the socket its replies.
	ourID uint16
	conn  pingConn
	out   chan []byte // echo requests, with ourID in them
	done  chan struct{}
	last  atomic.Int64 // when a packet last went either way, in UnixNano
	once  sync.Once
	lock  *sync.Mutex // the server's s.mu, see cone.lock
}

func (p *pinger) Close() error {
	p.lock.Lock()
	defer p.lock.Unlock()
	p.once.Do(func() { p.conn.Close(); close(p.done) })
	return nil
}

// handlePing takes an echo request from a device. Like handleUDP it runs on wireguard-go's receive
// goroutine and never blocks. False leaves the packet to the stack: anything but an echo request.
func (s *Server) handlePing(p []byte) bool {
	ip := header.IPv4(p)
	if len(p) < header.IPv4MinimumSize || p[0]>>4 != 4 || !ip.IsValid(len(p)) ||
		ip.TransportProtocol() != header.ICMPv4ProtocolNumber {
		return false
	}
	if ip.More() || ip.FragmentOffset() != 0 {
		return true // a fragmented ping is rare and not worth putting together: dropped
	}
	msg := header.ICMPv4(ip.Payload())
	if len(msg) < header.ICMPv4MinimumSize || msg.Type() != header.ICMPv4Echo || msg.Code() != 0 {
		return false
	}
	src, dst := netip.AddrFrom4(ip.SourceAddress().As4()), netip.AddrFrom4(ip.DestinationAddress().As4())
	if !forwardable(dst) {
		return true
	}
	pg := s.pinger(pingKey{device: src, dst: dst, id: msg.Ident()})
	if pg == nil {
		return true
	}
	req := make([]byte, len(msg))
	copy(req, msg)
	withIdent(req, pg.ourID)
	select {
	case pg.out <- req:
	default:
	}
	return true
}

// withIdent puts id in an echo message and makes its checksum again.
func withIdent(msg []byte, id uint16) {
	h := header.ICMPv4(msg)
	h.SetIdent(id)
	h.SetChecksum(0)
	h.SetChecksum(^checksum.Checksum(msg, 0))
}

// pinger returns the ping run's socket, making one. Nil when it can't.
func (s *Server) pinger(key pingKey) *pinger {
	s.mu.Lock()
	pg := s.pings[key]
	owner := s.ownerLocked(key.device)
	full := len(s.pings) >= maxPings
	listen := s.listenPing
	s.mu.Unlock()
	if pg != nil {
		if pg.owner != owner {
			return nil // SetPeers is closing it
		}
		return pg
	}
	if !owner.IsValid() || full {
		return nil
	}
	conn, err := listen()
	if err != nil {
		return nil
	}
	pg = &pinger{key: key, owner: owner, ourID: uint16(s.pingID.Add(1)), conn: conn,
		out: make(chan []byte, 16), done: make(chan struct{}), lock: &s.mu}
	pg.last.Store(time.Now().UnixNano())
	s.mu.Lock()
	if other := s.pings[key]; other != nil || s.ownerLocked(key.device) != owner || len(s.pings) >= maxPings {
		// Only handlePing makes pingers, on one goroutine, so this is a guard, see Server.cone.
		s.mu.Unlock()
		conn.Close()
		if other != nil && other.owner == owner {
			return other
		}
		return nil
	}
	s.pings[key] = pg
	untrack := s.trackLocked(owner, pg)
	s.mu.Unlock()
	s.conesRunning.Add(2)
	go func() { defer s.conesRunning.Done(); s.sendPings(pg) }()
	go func() {
		defer s.conesRunning.Done()
		s.receivePings(pg)
		pg.Close()
		untrack()
		s.mu.Lock()
		if s.pings[key] == pg {
			delete(s.pings, key)
		}
		s.mu.Unlock()
	}()
	return pg
}

func (s *Server) sendPings(pg *pinger) {
	to := &net.UDPAddr{IP: s.toNet(netip.AddrPortFrom(pg.key.dst, 0)).Addr().AsSlice()}
	for {
		var req []byte
		select {
		case req = <-pg.out:
		case <-pg.done:
			return
		}
		s.count(pg.owner, true, header.IPv4MinimumSize+len(req))
		if _, err := pg.conn.WriteTo(req, to); err == nil {
			pg.last.Store(time.Now().UnixNano())
		}
	}
}

// receivePings hands the destination's echo replies to the device, with its own identifier back.
func (s *Server) receivePings(pg *pinger) {
	buf := make([]byte, 65535)
	for {
		pg.conn.SetReadDeadline(time.Unix(0, pg.last.Load()).Add(pingIdle))
		n, from, err := pg.conn.ReadFrom(buf)
		if err != nil {
			if ne, ok := err.(net.Error); ok && ne.Timeout() && time.Since(time.Unix(0, pg.last.Load())) < pingIdle {
				continue
			}
			return
		}
		reply := header.ICMPv4(buf[:n])
		if n < header.ICMPv4MinimumSize || reply.Type() != header.ICMPv4EchoReply ||
			(runtime.GOOS != "linux" && reply.Ident() != pg.ourID) || fromAddr(from, s) != pg.key.dst {
			continue // someone else's reply, see pinger.ourID
		}
		pg.last.Store(time.Now().UnixNano())
		msg := make([]byte, n)
		copy(msg, reply)
		withIdent(msg, pg.key.id)
		packets := ipv4Packets(header.ICMPv4ProtocolNumber, tcpip.AddrFrom4(pg.key.dst.As4()),
			tcpip.AddrFrom4(pg.key.device.As4()), msg, s.nextID())
		s.count(pg.owner, false, header.IPv4MinimumSize+n)
		s.mu.Lock()
		select {
		case <-pg.done:
			s.mu.Unlock()
			return
		default:
		}
		for _, p := range packets {
			s.tun.inject(p)
		}
		s.mu.Unlock()
	}
}

// fromAddr is the host a reply came from, as the device knows it.
func fromAddr(from net.Addr, s *Server) netip.Addr {
	var ip net.IP
	switch a := from.(type) {
	case *net.UDPAddr:
		ip = a.IP
	case *net.IPAddr:
		ip = a.IP
	default:
		return netip.Addr{}
	}
	addr, ok := netip.AddrFromSlice(ip)
	if !ok {
		return netip.Addr{}
	}
	return s.fromNet(netip.AddrPortFrom(addr.Unmap(), 0)).Addr()
}
