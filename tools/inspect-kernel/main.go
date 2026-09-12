// inspect-kernel reports embedded FDT identities without executing an EFI image.
package main

import (
	"crypto/sha256"
	"debug/pe"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strings"
)

type dt struct {
	Model      string   `json:"model"`
	Compatible []string `json:"compatible"`
	SHA256     string   `json:"sha256"`
}

func u32(b []byte) uint32 { return binary.BigEndian.Uint32(b) }
func parse(b []byte) (dt, error) {
	r := dt{}
	if len(b) < 40 || u32(b) != 0xd00dfeed {
		return r, errors.New("invalid FDT header")
	}
	total, off, stroff := int(u32(b[4:])), int(u32(b[8:])), int(u32(b[12:]))
	if total > len(b) || off >= total || stroff >= total {
		return r, errors.New("FDT out of bounds")
	}
	h := sha256.Sum256(b[:total])
	r.SHA256 = hex.EncodeToString(h[:])
	depth := 0
	for off+4 <= total {
		token := u32(b[off:])
		off += 4
		switch token {
		case 1:
			end := off
			for end < total && b[end] != 0 {
				end++
			}
			if end == total {
				return r, errors.New("unterminated node")
			}
			off = (end + 4) & ^3
			depth++
		case 2:
			depth--
		case 3:
			if off+8 > total {
				return r, errors.New("short property")
			}
			n, no := int(u32(b[off:])), int(u32(b[off+4:]))
			off += 8
			if n > total-off || stroff+no >= total {
				return r, errors.New("property out of bounds")
			}
			end := stroff + no
			for end < total && b[end] != 0 {
				end++
			}
			if end == total {
				return r, errors.New("unterminated property name")
			}
			name := string(b[stroff+no : end])
			if depth == 1 {
				value := strings.TrimRight(string(b[off:off+n]), "\x00")
				if name == "model" {
					r.Model = value
				}
				if name == "compatible" {
					r.Compatible = strings.Split(value, "\x00")
				}
			}
			off = (off + n + 3) & ^3
		case 4:
		case 9:
			return r, nil
		default:
			return r, fmt.Errorf("unknown FDT token %d", token)
		}
	}
	return r, errors.New("missing FDT end token")
}
func run(path string) error {
	f, e := pe.Open(path)
	if e != nil {
		return e
	}
	defer f.Close()
	if f.Machine != pe.IMAGE_FILE_MACHINE_ARM64 {
		return errors.New("EFI image is not ARM64")
	}
	var trees []dt
	var hwids []hwid
	var sections []string
	lcd := false
	for _, s := range f.Sections {
		sections = append(sections, s.Name)
		if s.Name == ".hwids" {
			b, err := s.Data()
			if err != nil {
				return err
			}
			hwids, err = parseHWIDs(b)
			if err != nil {
				return err
			}
		}
		if s.Name != ".dtbauto" {
			continue
		}
		b, e := s.Data()
		if e != nil {
			return e
		}
		d, e := parse(b)
		if e != nil {
			return fmt.Errorf("section %s: %w", s.Name, e)
		}
		trees = append(trees, d)
		for _, c := range d.Compatible {
			if c == "lenovo,thinkpad-t14s-lcd" {
				lcd = true
			}
		}
	}
	r := map[string]any{"image": path, "architecture": "ARM64", "sections": sections, "device_trees": trees, "t14s_lcd_embedded": lcd, "signature_validation": "not performed by this tool", "hwid_matching": "not validated on target"}
	r["hwid_devices"] = hwids
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	if e := enc.Encode(r); e != nil {
		return e
	}
	if !lcd {
		return errors.New("no LCD T14s DTB found")
	}
	return nil
}
func main() {
	if len(os.Args) != 2 {
		fmt.Fprintln(os.Stderr, "usage: inspect-kernel IMAGE.EFI")
		os.Exit(2)
	}
	if e := run(os.Args[1]); e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(1)
	}
}
