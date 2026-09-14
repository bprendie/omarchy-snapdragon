package main

import (
	"errors"
	"os"
	"strings"
	"testing"
)

func fixture(t *testing.T) store {
	t.Helper()
	s := store{root: t.TempDir()}
	if err := s.initialize(); err != nil {
		t.Fatal(err)
	}
	return s
}

func TestDuplicateAndExplicitRetry(t *testing.T) {
	s := fixture(t)
	id := strings.Repeat("a", 64)
	for i := 0; i < 2; i++ {
		if err := s.enqueue(id, false); err != nil {
			t.Fatal(err)
		}
	}
	calls := 0
	fail := func(j job) (job, error) { calls++; return j, errors.New("initramfs failed") }
	if err := s.process(fail); err != nil {
		t.Fatal(err)
	}
	failed, err := s.read("failed", id)
	if err != nil || failed.Error != "initramfs failed" || failed.Work == "" {
		t.Fatalf("failure was lost: %+v %v", failed, err)
	}
	if err = s.enqueue(id, false); err != nil {
		t.Fatal(err)
	}
	if err = s.process(fail); err != nil {
		t.Fatal(err)
	}
	if calls != 1 {
		t.Fatal("failure automatically retried")
	}
	if err = s.enqueue(id, true); err != nil {
		t.Fatal(err)
	}
	if err = s.process(func(j job) (job, error) { calls++; j.Entry = strings.Repeat("b", 64); return j, nil }); err != nil {
		t.Fatal(err)
	}
	complete, err := s.read("complete", id)
	if err != nil || complete.Error != "" || complete.Work == failed.Work || calls != 2 {
		t.Fatal("explicit retry failed")
	}
}

func TestEnqueueDuringExecutionAndWorkerExclusion(t *testing.T) {
	s := fixture(t)
	a, b := strings.Repeat("a", 64), strings.Repeat("b", 64)
	if err := s.enqueue(a, false); err != nil {
		t.Fatal(err)
	}
	calls := 0
	if err := s.process(func(j job) (job, error) {
		calls++
		if calls == 1 {
			if err := s.enqueue(b, false); err != nil {
				t.Fatal(err)
			}
			if err := s.process(func(j job) (job, error) { t.Fatal("second worker executed"); return j, nil }); err == nil {
				t.Fatal("concurrent worker accepted")
			}
		}
		j.Entry = strings.Repeat("d", 64)
		return j, nil
	}); err != nil {
		t.Fatal(err)
	}
	if calls != 2 {
		t.Fatal("newly queued job not drained")
	}
}

func TestInterruptedJobBecomesVisibleFailure(t *testing.T) {
	s := fixture(t)
	id := strings.Repeat("a", 64)
	if err := s.enqueue(id, false); err != nil {
		t.Fatal(err)
	}
	if err := s.move("pending", "running", id); err != nil {
		t.Fatal(err)
	}
	if err := s.process(func(j job) (job, error) { t.Fatal("interrupted job retried automatically"); return j, nil }); err != nil {
		t.Fatal(err)
	}
	j, err := s.read("failed", id)
	if err != nil || !strings.Contains(j.Error, "interrupted") {
		t.Fatal("interruption not recorded")
	}
}

func TestCorruptOrSubstitutedJobRejected(t *testing.T) {
	s := fixture(t)
	id := strings.Repeat("a", 64)
	if err := os.Symlink("/missing", s.path("pending", id)); err != nil {
		t.Fatal(err)
	}
	if err := s.enqueue(id, false); err == nil {
		t.Fatal("substituted job accepted")
	}
	if err := s.process(func(j job) (job, error) { t.Fatal("invalid job executed"); return j, nil }); err == nil {
		t.Fatal("corrupt job silently ignored")
	}
}
