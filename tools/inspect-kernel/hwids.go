package main

import (
	"bytes"
	"encoding/binary"
	"fmt"
)

type hwid struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	Compatible string `json:"compatible"`
}

// Stubble's include/chid.h defines 28-byte Device records and section-relative strings.
func parseHWIDs(b []byte) ([]hwid, error) {
	var records []hwid
	str := func(offset uint32) (string, error) {
		if offset == 0 {
			return "", nil
		}
		if uint64(offset) >= uint64(len(b)) {
			return "", fmt.Errorf("HWID string offset out of bounds")
		}
		end := bytes.IndexByte(b[offset:], 0)
		if end < 0 {
			return "", fmt.Errorf("unterminated HWID string")
		}
		return string(b[offset : int(offset)+end]), nil
	}
	for off := 0; off+4 <= len(b); off += 28 {
		descriptor := binary.LittleEndian.Uint32(b[off:])
		if descriptor == 0 {
			return records, nil
		}
		kind := descriptor >> 28
		if descriptor&0x0fffffff != 28 || off+28 > len(b) || (kind != 1 && kind != 2) {
			return nil, fmt.Errorf("invalid HWID record at %d", off)
		}
		if kind != 1 {
			continue
		}
		g := b[off+4 : off+20]
		id := fmt.Sprintf("%08x-%04x-%04x-%x-%x", binary.LittleEndian.Uint32(g), binary.LittleEndian.Uint16(g[4:]), binary.LittleEndian.Uint16(g[6:]), g[8:10], g[10:])
		name, err := str(binary.LittleEndian.Uint32(b[off+20:]))
		if err != nil {
			return nil, err
		}
		compatible, err := str(binary.LittleEndian.Uint32(b[off+24:]))
		if err != nil {
			return nil, err
		}
		records = append(records, hwid{id, name, compatible})
	}
	return nil, fmt.Errorf("missing HWID end marker")
}
