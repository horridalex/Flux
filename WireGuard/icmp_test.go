package main

import (
	"bytes"
	"net"
	"net/netip"
	"os"
	"sync"
	"testing"
	"time"

	"golang.org/x/net/icmp"
	"golang.org/x/net/ipv4"
	"gvisor.dev/gvisor/pkg/tcpip/header"
)

// echoConn is an ICMP socket whose every echo request gets a reply from the host it went to, the
// way the iPhone's socket gets one from a host that's up. Requests to down get nothing.
type echoConn struct {
	down    netip.Addr
	replies chan echoReply
	sent    chan []byte // every request, for the test to look at
	mu      sync.Mutex
	until   time.Time
	closed  chan struct{}
	once    sync.Once
}

type echoReply struct {
	msg  []byte
	from net.Addr
}

// answerPings has the server ping with listen instead of a real ICMP socket.
func answerPings(s *Server, listen func() (pingConn, error)) {
	s.mu.Lock()
	s.listenPing = listen
	s.mu.Unlock()
}

func newEchoConn(down netip.Addr) *echoConn {
	return &echoConn{down: down, replies: make(chan echoReply, 16), sent: make(chan []byte, 16), closed: make(chan struct{})}
}

func (c *echoConn) WriteTo(b []byte, dst net.Addr) (int, error) {
	msg := append([]byte(nil), b...)
	select {
	case c.sent <- msg:
	default:
	}
	to := dst.(*net.UDPAddr)
	if addr, _ := netip.AddrFromSlice(to.IP); addr.Unmap() == c.down {
		return len(b), nil
	}
	reply := append([]byte(nil), b...)
	reply[0] = byte(header.ICMPv4EchoReply)
	withIdent(reply, header.ICMPv4(reply).Ident())
	c.replies <- echoReply{reply, to}
	return len(b), nil
}

func (c *echoConn) ReadFrom(b []byte) (int, net.Addr, error) {
	c.mu.Lock()
	until := c.until
	c.mu.Unlock()
	timer := time.NewTimer(time.Until(until))
	defer timer.Stop()
	select {
	case r := <-c.replies:
		return copy(b, r.msg), r.from, nil
	case <-timer.C:
		return 0, nil, os.ErrDeadlineExceeded
	case <-c.closed:
		return 0, nil, net.ErrClosed
	}
}

func (c *echoConn) SetReadDeadline(t time.Time) error {
	c.mu.Lock()
	c.until = t
	c.mu.Unlock()
	return nil
}

func (c *echoConn) Close() error {
	c.once.Do(func() { close(c.closed) })
	return nil
}

// ping sends one echo request through the tunnel and returns the reply, or an error after a while.
func ping(t *testing.T, c *client, to string, seq int, data []byte) (*icmp.Echo, error) {
	t.Helper()
	conn, err := c.net.Dial("ping4", to)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	req, _ := (&icmp.Message{Type: ipv4.ICMPTypeEcho, Body: &icmp.Echo{ID: 1234, Seq: seq, Data: data}}).Marshal(nil)
	if _, err := conn.Write(req); err != nil {
		t.Fatal(err)
	}
	conn.SetReadDeadline(time.Now().Add(2 * time.Second))
	buf := make([]byte, 65535)
	n, err := conn.Read(buf)
	if err != nil {
		return nil, err
	}
	m, err := icmp.ParseMessage(1, buf[:n])
	if err != nil {
		t.Fatal(err)
	}
	if m.Type != ipv4.ICMPTypeEchoReply {
		t.Fatalf("got %v, want an echo reply", m.Type)
	}
	return m.Body.(*icmp.Echo), nil
}

func TestPingGetsTheHostsReply(t *testing.T) {
	s, c := setup(t)
	fake := newEchoConn(netip.Addr{})
	answerPings(s, func() (pingConn, error) { return fake, nil })

	data := []byte("are you there")
	echo, err := ping(t, c, "203.0.113.5", 7, data)
	if err != nil {
		t.Fatal(err)
	}
	if echo.Seq != 7 || !bytes.Equal(echo.Data, data) {
		t.Fatalf("got seq %d data %q", echo.Seq, echo.Data)
	}
	// The iPhone sent it with an identifier of its own, see pinger.ourID.
	sent := <-fake.sent
	if header.ICMPv4(sent).Ident() == 0 {
		t.Fatal("sent with no identifier of the iPhone's")
	}
	st := s.Stats()
	if d := st.Devices["10.7.0.2"]; d.Up == 0 || d.Down == 0 {
		t.Fatalf("the ping isn't counted as the device's: %+v", st.Devices)
	}
}

func TestPingToAHostThatIsDownGetsNothing(t *testing.T) {
	s, c := setup(t)
	answerPings(s, func() (pingConn, error) { return newEchoConn(netip.MustParseAddr("203.0.113.6")), nil })
	if _, err := ping(t, c, "203.0.113.6", 1, nil); err == nil {
		t.Fatal("a reply from a host that never answered")
	}
}

func TestPingStaysOffTheTunnelAndLoopback(t *testing.T) {
	s, c := setup(t)
	opened := 0
	answerPings(s, func() (pingConn, error) { opened++; return newEchoConn(netip.Addr{}), nil })
	for _, to := range []string{"10.7.0.3", "127.0.0.1", "224.0.0.251"} {
		if _, err := ping(t, c, to, 1, nil); err == nil {
			t.Fatalf("a reply from %s", to)
		}
	}
	if opened != 0 {
		t.Fatalf("opened %d ICMP sockets for addresses that stay inside", opened)
	}
}

func TestRemovedDeviceLosesItsPings(t *testing.T) {
	s, c := setup(t)
	answerPings(s, func() (pingConn, error) { return newEchoConn(netip.Addr{}), nil })
	if _, err := ping(t, c, "203.0.113.5", 1, nil); err != nil {
		t.Fatal(err)
	}
	if err := s.SetPeers(nil); err != nil {
		t.Fatal(err)
	}
	s.mu.Lock()
	n := len(s.pings)
	s.mu.Unlock()
	deadline := time.Now().Add(2 * time.Second)
	for n > 0 && time.Now().Before(deadline) {
		time.Sleep(10 * time.Millisecond)
		s.mu.Lock()
		n = len(s.pings)
		s.mu.Unlock()
	}
	if n != 0 {
		t.Fatalf("%d pings still open after the device was removed", n)
	}
	if _, ok := s.Stats().Devices["10.7.0.2"]; ok {
		t.Fatal("a removed device's totals stayed")
	}
}

// The real iPhone-side socket, pinging loopback. Skipped where the system doesn't allow
// unprivileged ICMP sockets (Linux without ping_group_range). macOS and iOS do.
func TestPingWithARealSocket(t *testing.T) {
	probe, err := listenICMP()
	if err != nil {
		t.Skip("no unprivileged ICMP here:", err)
	}
	probe.Close()
	_, c := setup(t) // viaLoopback sends what goes to remote to 127.0.0.1
	echo, err := ping(t, c, remote, 3, []byte("hello"))
	if err != nil {
		t.Fatal(err)
	}
	if echo.Seq != 3 || string(echo.Data) != "hello" {
		t.Fatalf("got seq %d data %q", echo.Seq, echo.Data)
	}
}
