package main

import (
	"context"
	"io"
	"net"
	"testing"
	"time"
)

// The benchmarks move bulk TCP through a real WireGuard client and the server over loopback, the
// way a download or an upload goes through Flux. The client's own netstack runs in the same
// process, so the numbers include its work too: compare them with each other, not with a phone.
//
//	go -C WireGuard test -run '^$' -bench . -cpu 1 -benchtime 15x -count 8
//
// One CPU makes it CPU-bound, the way a phone is at high speeds, so a change that saves work shows.

const benchBytes = 16 << 20

// sink takes an upload and says how much arrived, after the device closes its side.
func sink(t testing.TB) string {
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { l.Close() })
	go func() {
		for {
			c, err := l.Accept()
			if err != nil {
				return
			}
			go func() {
				defer c.Close()
				io.Copy(io.Discard, c)
			}()
		}
	}()
	return viaRemote(l.Addr().String())
}

func BenchmarkTCPDownload(b *testing.B) {
	_, c := setup(b)
	addr := tcpServer(b, benchBytes)
	b.SetBytes(benchBytes)
	b.ResetTimer()
	for range b.N {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		conn, err := c.net.DialContext(ctx, "tcp", addr)
		cancel()
		if err != nil {
			b.Fatal(err)
		}
		conn.Write([]byte("hello"))
		// Discarded, not kept: keeping 16 MB would cost more than the tunnel.
		if n, err := io.Copy(io.Discard, conn); err != nil || n != benchBytes {
			b.Fatalf("got %d bytes, %v", n, err)
		}
		conn.Close()
	}
}

func BenchmarkTCPUpload(b *testing.B) {
	_, c := setup(b)
	addr := sink(b)
	payload := make([]byte, 64<<10)
	b.SetBytes(benchBytes)
	b.ResetTimer()
	for range b.N {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		conn, err := c.net.DialContext(ctx, "tcp", addr)
		cancel()
		if err != nil {
			b.Fatal(err)
		}
		for sent := 0; sent < benchBytes; sent += len(payload) {
			if _, err := conn.Write(payload); err != nil {
				b.Fatal(err)
			}
		}
		conn.Close()
	}
}

func TestWireGuardTakesPacketsInBatches(t *testing.T) {
	s, _ := setup(t)
	if got := s.tun.BatchSize(); got != tunBatch {
		t.Fatalf("batch %d, want %d", got, tunBatch)
	}
}
