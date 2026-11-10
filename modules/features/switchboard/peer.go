package main

// Who is on the other end of a loopback connection.
//
// 127.0.0.1 is shared by every account on the machine, and whoever can use the
// web UI's API can switch the system — so the server answers only to the user
// who started it. (The work user has no sudo on purpose; a server that took
// its requests would hand it one.) TCP has no SO_PEERCRED, so the owner of the
// client's socket is read from the kernel's socket table, /proc/net/tcp{,6}.

import (
	"encoding/binary"
	"errors"
	"fmt"
	"net/netip"
	"os"
	"strconv"
	"strings"
)

// peerUID returns the uid owning the client socket of a TCP connection that
// was accepted on local from remote.
func peerUID(local, remote netip.AddrPort) (uint32, error) {
	local = netip.AddrPortFrom(local.Addr().Unmap(), local.Port())
	remote = netip.AddrPortFrom(remote.Addr().Unmap(), remote.Port())

	type table struct {
		path string
		as16 bool
	}
	tables := []table{{"/proc/net/tcp6", true}}
	if remote.Addr().Is4() {
		// An IPv4 peer is normally in the v4 table; a client that used a
		// dual-stack socket shows up in the v6 one, as ::ffff:a.b.c.d.
		tables = []table{{"/proc/net/tcp", false}, {"/proc/net/tcp6", true}}
	}
	var firstErr error
	for _, t := range tables {
		data, err := os.ReadFile(t.path)
		if err != nil {
			if firstErr == nil {
				firstErr = err
			}
			continue
		}
		// The client's own socket: its local end is our remote one.
		if uid, ok := socketOwner(data, procAddr(remote, t.as16), procAddr(local, t.as16)); ok {
			return uid, nil
		}
	}
	if firstErr != nil {
		return 0, firstErr
	}
	return 0, errors.New("the connection's client socket is not in the kernel's socket table")
}

// procAddr renders an address the way /proc/net/tcp{,6} prints it: each
// 32-bit word of the address as the kernel holds it, in hex, then the port.
// 127.0.0.1:7391 is 0100007F:1CDF on a little-endian machine.
func procAddr(ap netip.AddrPort, as16 bool) string {
	raw := ap.Addr().AsSlice()
	if as16 {
		wide := ap.Addr().As16()
		raw = wide[:]
	}
	var b strings.Builder
	for i := 0; i+4 <= len(raw); i += 4 {
		fmt.Fprintf(&b, "%08X", binary.NativeEndian.Uint32(raw[i:]))
	}
	fmt.Fprintf(&b, ":%04X", ap.Port())
	return b.String()
}

// socketOwner finds the socket with the given ends in a /proc/net/tcp{,6}
// table and returns the uid column.
func socketOwner(table []byte, local, remote string) (uint32, bool) {
	for _, line := range strings.Split(string(table), "\n") {
		// sl local_address rem_address st tx:rx tr:when retrnsmt uid …
		f := strings.Fields(line)
		if len(f) < 8 || f[1] != local || f[2] != remote {
			continue
		}
		uid, err := strconv.ParseUint(f[7], 10, 32)
		if err != nil {
			return 0, false
		}
		return uint32(uid), true
	}
	return 0, false
}
