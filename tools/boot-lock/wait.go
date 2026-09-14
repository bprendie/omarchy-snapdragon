package bootlock

import (
	"context"
	"encoding/binary"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"syscall"
	"time"
)

func AcquireSystemFor(duration time.Duration) (*Lock, error) {
	if duration < 0 || duration > 30*time.Minute {
		return nil, fmt.Errorf("lock wait must be between zero and 30 minutes")
	}
	if duration == 0 {
		return AcquireSystem()
	}
	ctx, cancel := context.WithTimeout(context.Background(), duration)
	defer cancel()
	return WaitSystem(ctx)
}

func WaitSystem(ctx context.Context) (*Lock, error) {
	path, err := systemPath()
	if err != nil {
		return nil, err
	}
	return Wait(ctx, path)
}

// Wait watches before attempting exclusive creation, closing the lost-wakeup
// window between observing a busy database and starting to watch for release.
func Wait(ctx context.Context, path string) (*Lock, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	fd, err := syscall.InotifyInit1(syscall.IN_CLOEXEC | syscall.IN_NONBLOCK)
	if err != nil {
		return nil, err
	}
	file := os.NewFile(uintptr(fd), "pacman-lock-events")
	defer file.Close()
	mask := uint32(syscall.IN_CREATE | syscall.IN_DELETE | syscall.IN_MOVED_FROM | syscall.IN_MOVED_TO | syscall.IN_DELETE_SELF | syscall.IN_MOVE_SELF | syscall.IN_ONLYDIR)
	if _, err = syscall.InotifyAddWatch(fd, filepath.Dir(path), mask); err != nil {
		return nil, err
	}
	done := make(chan struct{})
	defer close(done)
	go func() {
		select {
		case <-ctx.Done():
			_ = file.Close()
		case <-done:
		}
	}()
	buffer := make([]byte, 16384)
	for {
		if err = ctx.Err(); err != nil {
			return nil, err
		}
		lock, err := Acquire(path)
		if err == nil {
			return lock, nil
		}
		if !errors.Is(err, os.ErrExist) {
			return nil, err
		}
		n, err := file.Read(buffer)
		if err != nil {
			if ctx.Err() != nil {
				return nil, ctx.Err()
			}
			return nil, err
		}
		for offset := 0; offset+syscall.SizeofInotifyEvent <= n; {
			flags := binary.NativeEndian.Uint32(buffer[offset+4 : offset+8])
			size := int(binary.NativeEndian.Uint32(buffer[offset+12 : offset+16]))
			if flags&(syscall.IN_IGNORED|syscall.IN_Q_OVERFLOW|syscall.IN_DELETE_SELF|syscall.IN_MOVE_SELF) != 0 {
				return nil, fmt.Errorf("pacman lock watch invalidated; no lock was removed")
			}
			offset += syscall.SizeofInotifyEvent + size
		}
	}
}
