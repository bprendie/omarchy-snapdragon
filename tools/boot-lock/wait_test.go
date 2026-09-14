package bootlock

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestWaitExpiresWithoutChangingOwner(t *testing.T) {
	path := filepath.Join(t.TempDir(), "db.lck")
	held, err := Acquire(path)
	if err != nil {
		t.Fatal(err)
	}
	defer held.Close()
	before, _ := os.ReadFile(path)
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Millisecond)
	defer cancel()
	if _, err = Wait(ctx, path); !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("expected deadline, got %v", err)
	}
	after, _ := os.ReadFile(path)
	if string(before) != string(after) {
		t.Fatal("owner's lock changed")
	}
}

func TestWaitAcquiresAfterRelease(t *testing.T) {
	path := filepath.Join(t.TempDir(), "db.lck")
	held, err := Acquire(path)
	if err != nil {
		t.Fatal(err)
	}
	released := make(chan error, 1)
	time.AfterFunc(20*time.Millisecond, func() { released <- held.Close() })
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	next, err := Wait(ctx, path)
	if err != nil {
		t.Fatal(err)
	}
	defer next.Close()
	if err = <-released; err != nil {
		t.Fatal(err)
	}
}

func TestCancelledWaitDoesNotCreateLock(t *testing.T) {
	path := filepath.Join(t.TempDir(), "db.lck")
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := Wait(ctx, path); !errors.Is(err, context.Canceled) {
		t.Fatal(err)
	}
	if _, err := os.Lstat(path); !os.IsNotExist(err) {
		t.Fatal("cancelled wait created a lock")
	}
}

func TestInvalidSystemWaitBounds(t *testing.T) {
	for _, duration := range []time.Duration{-time.Second, 31 * time.Minute} {
		if _, err := AcquireSystemFor(duration); err == nil {
			t.Fatal("invalid wait bound accepted")
		}
	}
}
