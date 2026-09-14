// Test helper: hold the production lock until the controlling pipe closes.
package main

import (
	"flag"
	"fmt"
	"io"
	bootlock "oma_snap/boot-lock"
	"os"
)

func run() (result error) {
	wait := flag.Duration("wait-lock", 0, "test bounded event-based waiting")
	flag.Parse()
	lock, err := bootlock.AcquireSystemFor(*wait)
	if err != nil {
		return err
	}
	defer func() {
		if err := lock.Close(); result == nil {
			result = err
		}
	}()
	fmt.Println("LOCK_HELD")
	_, err = io.Copy(io.Discard, os.Stdin)
	return err
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
