// image-delta replaces changed blocks only after verifying the complete old image.
package main

import (
	"bytes"
	"crypto/sha256"
	"flag"
	"fmt"
	"io"
	"os"
)

func digest(f *os.File, size int64) ([]byte, error) {
	if _, err := f.Seek(0, 0); err != nil {
		return nil, err
	}
	h := sha256.New()
	n, err := io.Copy(h, io.LimitReader(f, size))
	if err != nil {
		return nil, err
	}
	if n != size {
		return nil, fmt.Errorf("short read: %d of %d", n, size)
	}
	return h.Sum(nil), nil
}

func run(apply bool, paths []string) error {
	old, err := os.Open(paths[0])
	if err != nil {
		return err
	}
	defer old.Close()
	next, err := os.Open(paths[1])
	if err != nil {
		return err
	}
	defer next.Close()
	a, err := old.Stat()
	if err != nil {
		return err
	}
	b, err := next.Stat()
	if err != nil {
		return err
	}
	if !a.Mode().IsRegular() || !b.Mode().IsRegular() || a.Size() == 0 || a.Size() != b.Size() {
		return fmt.Errorf("inputs must be equal-sized, nonempty regular images")
	}
	var target *os.File
	if apply {
		target, err = os.OpenFile(paths[2], os.O_RDWR, 0)
		if err != nil {
			return err
		}
		defer target.Close()
		st, err := target.Stat()
		if err != nil {
			return err
		}
		if os.SameFile(a, st) || os.SameFile(b, st) {
			return fmt.Errorf("target aliases an input")
		}
		expected, err := digest(old, a.Size())
		if err != nil {
			return err
		}
		actual, err := digest(target, a.Size())
		if err != nil {
			return err
		}
		if !bytes.Equal(expected, actual) {
			return fmt.Errorf("target does not match old image; refusing writes")
		}
		fmt.Printf("Verified old image: %x\n", actual)
	}
	const block = 4 * 1024 * 1024
	left, right := make([]byte, block), make([]byte, block)
	var changed int64
	for offset := int64(0); offset < a.Size(); offset += block {
		n := min(int64(block), a.Size()-offset)
		if _, err := old.ReadAt(left[:n], offset); err != nil {
			return err
		}
		if _, err := next.ReadAt(right[:n], offset); err != nil {
			return err
		}
		if bytes.Equal(left[:n], right[:n]) {
			continue
		}
		fmt.Printf("Changed offset=%d bytes=%d\n", offset, n)
		changed += n
		if apply {
			if written, err := target.WriteAt(right[:n], offset); err != nil || int64(written) != n {
				return fmt.Errorf("write at %d: %d bytes, %v", offset, written, err)
			}
		}
	}
	if apply {
		if err := target.Sync(); err != nil {
			return err
		}
		expected, err := digest(next, b.Size())
		if err != nil {
			return err
		}
		actual, err := digest(target, b.Size())
		if err != nil {
			return err
		}
		if !bytes.Equal(expected, actual) {
			return fmt.Errorf("final target checksum mismatch")
		}
		fmt.Printf("Verified new image: %x\n", actual)
	}
	fmt.Printf("Changed bytes: %d of %d (apply=%t)\n", changed, a.Size(), apply)
	return nil
}

func main() {
	apply := flag.Bool("apply", false, "write to a target already matching the old image")
	flag.Parse()
	want := 2
	if *apply {
		want = 3
	}
	if flag.NArg() != want {
		fmt.Fprintln(os.Stderr, "usage: image-delta [-apply] old.iso new.iso [target]")
		os.Exit(2)
	}
	if err := run(*apply, flag.Args()); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
