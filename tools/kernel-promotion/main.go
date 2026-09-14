package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
)

func main() {
	approval := flag.String("approval", "", "maintainer-reviewed approval JSON")
	archive := flag.String("package", "", "exact retained hardware package")
	previous := flag.Uint64("previous-sequence", 0, "last published provider sequence (0 for first release)")
	out := flag.String("output", "", "new provider build directory")
	flag.Parse()
	if err := generate(*approval, *archive, *out, *previous); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func generate(record, archive, out string, previous uint64) error {
	if record == "" || archive == "" || out == "" {
		return fmt.Errorf("--approval, --package and --output are required")
	}
	var a approval
	if err := readJSON(record, &a); err != nil {
		return err
	}
	if err := a.verify(filepath.Dir(record), archive, previous); err != nil {
		return err
	}
	data, err := json.MarshalIndent(a, "", "  ")
	if err != nil {
		return err
	}
	if err = os.Mkdir(out, 0755); err != nil {
		return err
	}
	complete := false
	defer func() {
		if !complete {
			os.RemoveAll(out)
		}
	}()
	// Pacman authenticates this record through the signed provider package.
	if err = os.WriteFile(filepath.Join(out, "candidate.json"), append(data, '\n'), 0644); err != nil {
		return err
	}
	build := fmt.Sprintf(`pkgname=oma-snap-kernel
epoch=1
pkgver=%d
pkgrel=1
pkgdesc='Approved Ubuntu-derived Snapdragon kernel provider'
arch=('aarch64')
license=('custom')
depends=('oma-snap-set-%s=0.2.0-1' 'oma-snap-kernel-tools>=0.2.0-10')
options=('!strip' '!debug')
package() {
  install -Dm644 "$startdir/candidate.json" "$pkgdir/usr/share/oma-snap/kernel-provider/candidate.json"
}
`, a.Sequence, a.HardwareSet)
	if err = os.WriteFile(filepath.Join(out, "PKGBUILD"), []byte(build), 0644); err != nil {
		return err
	}
	complete = true
	fmt.Printf("Prepared %s provider sequence %d; not built, signed or published\n", a.Channel, a.Sequence)
	return nil
}
