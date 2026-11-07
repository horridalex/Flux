package main

import (
	"net"
	"net/netip"
	"sync"

	"golang.zx2c4.com/wireguard/conn"
)

// hostBind is a conn.Bind that listens on one address only, the hotspot's.
// wireguard-go's own bind listens on every interface.

// socketBuffer is what hostBind asks for each way, as wireguard-go's own bind does. The default is
// far smaller, and a device that sends a burst (an upload, say) overflows it: the packets are lost
// and its TCP waits to send them again. A system that allows less gets the most it allows.
const socketBuffer = 7 << 20

type hostBind struct {
	host netip.Addr
	mu   sync.Mutex
	c    *net.UDPConn
}

type endpoint struct{ netip.AddrPort }

func (e endpoint) ClearSrc()           {}
func (e endpoint) SrcToString() string { return "" }
func (e endpoint) DstToString() string { return e.AddrPort.String() }
func (e endpoint) DstToBytes() []byte  { b, _ := e.AddrPort.MarshalBinary(); return b }
func (e endpoint) DstIP() netip.Addr   { return e.AddrPort.Addr() }
func (e endpoint) SrcIP() netip.Addr   { return netip.Addr{} }

func (b *hostBind) Open(port uint16) ([]conn.ReceiveFunc, uint16, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	if b.c != nil {
		return nil, 0, conn.ErrBindAlreadyOpen
	}
	c, err := net.ListenUDP("udp", net.UDPAddrFromAddrPort(netip.AddrPortFrom(b.host, port)))
	if err != nil {
		return nil, 0, err
	}
	setBuffers(c)
	b.c = c
	receive := func(packets [][]byte, sizes []int, eps []conn.Endpoint) (int, error) {
		n, from, err := c.ReadFromUDPAddrPort(packets[0])
		if err != nil {
			return 0, err
		}
		sizes[0] = n
		eps[0] = endpoint{netip.AddrPortFrom(from.Addr().Unmap(), from.Port())}
		return 1, nil
	}
	return []conn.ReceiveFunc{receive}, uint16(c.LocalAddr().(*net.UDPAddr).Port), nil
}

func (b *hostBind) Close() error {
	b.mu.Lock()
	defer b.mu.Unlock()
	if b.c == nil {
		return nil
	}
	err := b.c.Close()
	b.c = nil
	return err
}

func (b *hostBind) Send(bufs [][]byte, ep conn.Endpoint) error {
	b.mu.Lock()
	c := b.c
	b.mu.Unlock()
	if c == nil {
		return net.ErrClosed
	}
	e, ok := ep.(endpoint)
	if !ok {
		return conn.ErrWrongEndpointType
	}
	for _, buf := range bufs {
		if _, err := c.WriteToUDPAddrPort(buf, e.AddrPort); err != nil {
			return err
		}
	}
	return nil
}

func (b *hostBind) ParseEndpoint(s string) (conn.Endpoint, error) {
	ap, err := netip.ParseAddrPort(s)
	return endpoint{ap}, err
}

func (b *hostBind) SetMark(uint32) error { return nil }
func (b *hostBind) BatchSize() int       { return 1 }

// setBuffers asks for socketBuffer each way, then for half as much until the system agrees.
// macOS and iOS refuse more than kern.ipc.maxsockbuf, where Linux quietly caps it.
func setBuffers(c *net.UDPConn) {
	for size := socketBuffer; size >= 256<<10; size /= 2 {
		if c.SetReadBuffer(size) == nil {
			break
		}
	}
	for size := socketBuffer; size >= 256<<10; size /= 2 {
		if c.SetWriteBuffer(size) == nil {
			break
		}
	}
}
