package main

import (
	"encoding/binary"
	"testing"
)

func TestHWIDDecodeAndBounds(t *testing.T) {
	b := make([]byte, 32)
	binary.LittleEndian.PutUint32(b, 0x1000001c)
	copy(b[4:20], []byte{0xdf, 0x9f, 0x57, 0x83, 0xaf, 0x8f, 0xb4, 0x57, 0xb2, 0x65, 0xd2, 0xe8, 0x17, 0xc7, 0xcf, 0x3f})
	binary.LittleEndian.PutUint32(b[24:], 32)
	b = append(b, []byte("lenovo,thinkpad-t14s-lcd\x00")...)
	r, err := parseHWIDs(b)
	if err != nil || len(r) != 1 || r[0].ID != "83579fdf-8faf-57b4-b265-d2e817c7cf3f" || r[0].Compatible != "lenovo,thinkpad-t14s-lcd" {
		t.Fatalf("unexpected decode: %+v, %v", r, err)
	}
	if _, err := parseHWIDs(b[:27]); err == nil {
		t.Fatal("accepted truncated record")
	}
	if _, err := parseHWIDs(b[:len(b)-1]); err == nil {
		t.Fatal("accepted unterminated string")
	}
	binary.LittleEndian.PutUint32(b[24:], 0xffffffff)
	if _, err := parseHWIDs(b); err == nil {
		t.Fatal("accepted out-of-bounds string")
	}
}
