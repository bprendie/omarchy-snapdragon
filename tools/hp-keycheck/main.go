// hp-keycheck observes only the HP keyboard's media/function reports for 60s.
package main

import (
	"encoding/binary"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func main() {
	devices, err := filepath.Glob("/sys/bus/hid/devices/*:0416:C300.*")
	if err != nil || len(devices) != 1 {
		fail("Expected exactly one HP 0416:C300 keyboard")
	}
	nodes, err := filepath.Glob(devices[0] + "/hidraw/hidraw*")
	if err != nil || len(nodes) != 1 {
		fail("Expected one keyboard hidraw interface")
	}
	f, err := os.Open("/dev/" + filepath.Base(nodes[0]))
	if err != nil {
		fail(err.Error())
	}
	defer f.Close()
	fmt.Println("READY: press brightness, volume and mute, alone and with Fn.")
	fmt.Println("60 seconds; ordinary letter/digit reports are omitted; no input grab.")
	time.AfterFunc(60*time.Second, func() {
		fmt.Println("Capture complete")
		os.Exit(0)
	})
	buf := make([]byte, 4096)
	for {
		n, err := f.Read(buf)
		if err != nil {
			fail(err.Error())
		}
		if n == 0 {
			continue
		}
		switch buf[0] {
		case 9:
			if n >= 3 {
				fmt.Printf("media report: usage=%#04x length=%d\n", binary.LittleEndian.Uint16(buf[1:3]), n)
			}
		case 8:
			if n < 4 {
				continue
			}
			var keys []string
			for _, key := range buf[3:n] {
				switch {
				case key >= 0x3a && key <= 0x45:
					keys = append(keys, fmt.Sprintf("F%d", key-0x3a+1))
				case key >= 0x68 && key <= 0x73:
					keys = append(keys, fmt.Sprintf("F%d (usage=%#02x)", key-0x68+13, key))
				case key >= 0x39 && !(key >= 0x59 && key <= 0x63):
					keys = append(keys, fmt.Sprintf("usage=%#02x", key))
				}
			}
			if len(keys) > 0 {
				fmt.Printf("keyboard report: %s modifiers=%#02x\n", strings.Join(keys, ","), buf[1])
			}
		default:
			fmt.Printf("other report: id=%d length=%d\n", buf[0], n)
		}
	}
}

func fail(message string) {
	fmt.Fprintln(os.Stderr, message)
	os.Exit(1)
}
