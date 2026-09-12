package main

import (
	"context"
	"errors"
	"path/filepath"
	"syscall"
	"testing"
	"time"
)

func TestBlockedReadReturnsAtDeadline(t *testing.T) {
	pipe := filepath.Join(t.TempDir(), "blocked-read")
	if err := syscall.Mkfifo(pipe, 0600); err != nil {
		t.Fatal(err)
	}
	start := time.Now()
	_, err := command(100*time.Millisecond, "cat", pipe)
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("got %v", err)
	}
	if time.Since(start) > time.Second {
		t.Fatal("blocked read exceeded deadline")
	}
	data, err := command(time.Second, "printf", "still collecting")
	if err != nil || string(data) != "still collecting" {
		t.Fatalf("subsequent capture: %q %v", data, err)
	}
}
