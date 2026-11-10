package main

import (
	"encoding/binary"
	"net"
	"net/netip"
	"os"
	"testing"
)

// Two lines as the kernel prints them: the server's listening socket, and a
// client (uid 1001) connected to it from port 0xA12A.
const procTCPFixture = `  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode
   1: 0100007F:1CDF 00000000:0000 0A 00000000:00000000 00:00000000 00000000  1000        0 575317 2 0000000000000000 100 0 0 10 0
  17: 0100007F:A12A 0100007F:1CDF 01 00000000:00000000 02:00000000 00000000  1001        0 566216 2 0000000000000000 20 4 0 10 -1
  27: 0100007F:1CDF 0100007F:A12A 01 00000000:00000000 02:000001E7 00000000  1000        0 570160 2 0000000000000000 20 4 31 10 -1
`

func TestSocketOwner(t *testing.T) {
	// The client's socket — not the server's accepted end of the same
	// connection, which belongs to the server's user.
	uid, ok := socketOwner([]byte(procTCPFixture), "0100007F:A12A", "0100007F:1CDF")
	if !ok || uid != 1001 {
		t.Errorf("owner of the client socket = %d, %v; want 1001", uid, ok)
	}
	if _, ok := socketOwner([]byte(procTCPFixture), "0100007F:BEEF", "0100007F:1CDF"); ok {
		t.Error("a socket that is not in the table must not be found")
	}
}

func TestProcAddr(t *testing.T) {
	if binary.NativeEndian.Uint16([]byte{1, 0}) != 1 {
		t.Skip("the expected strings are the little-endian rendering")
	}
	v4 := netip.MustParseAddrPort("127.0.0.1:7391")
	cases := []struct {
		ap   netip.AddrPort
		as16 bool
		want string
	}{
		{v4, false, "0100007F:1CDF"},
		{v4, true, "0000000000000000FFFF00000100007F:1CDF"},
		{netip.MustParseAddrPort("[::1]:7391"), true, "00000000000000000000000001000000:1CDF"},
	}
	for _, c := range cases {
		if got := procAddr(c.ap, c.as16); got != c.want {
			t.Errorf("procAddr(%v, %v) = %s, want %s", c.ap, c.as16, got, c.want)
		}
	}
}

// The real thing, end to end: a connection this test opens to itself is
// owned by the user running the test.
func TestPeerUIDOfALoopbackConnection(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	client, err := net.Dial("tcp", ln.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()
	server, err := ln.Accept()
	if err != nil {
		t.Fatal(err)
	}
	defer server.Close()

	uid, err := peerUID(
		server.LocalAddr().(*net.TCPAddr).AddrPort(),
		server.RemoteAddr().(*net.TCPAddr).AddrPort(),
	)
	if err != nil {
		t.Fatal(err)
	}
	if uid != uint32(os.Getuid()) {
		t.Errorf("peerUID = %d, want this process's uid %d", uid, os.Getuid())
	}
}
