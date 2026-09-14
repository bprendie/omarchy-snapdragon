package main

import (
	"fmt"
	"os"
	"strings"
)

func run() error {
	if len(os.Args) != 3 {
		return fmt.Errorf("usage: overlay-header INPUT.dtbo OUTPUT.h")
	}
	data, err := os.ReadFile(os.Args[1])
	if err != nil {
		return err
	}
	if len(data) < 40 || string(data[:4]) != "\xd0\x0d\xfe\xed" {
		return fmt.Errorf("invalid DT overlay header")
	}
	var text strings.Builder
	text.WriteString("static const unsigned char overlay_data[] __aligned(8) = {\n")
	for _, b := range data {
		fmt.Fprintf(&text, "0x%02x,", b)
	}
	text.WriteString("\n};\n")
	return os.WriteFile(os.Args[2], []byte(text.String()), 0644)
}
func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
