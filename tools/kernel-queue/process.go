package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
)

func (s store) process(execute func(job) (job, error)) error {
	worker, err := os.OpenFile(filepath.Join(s.root, "worker.lock"), os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return err
	}
	defer worker.Close()
	if err = syscall.Flock(int(worker.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		return fmt.Errorf("another preparation worker is active: %w", err)
	}
	for {
		processed, err := s.processOne(execute)
		if err != nil {
			return err
		}
		if !processed {
			return nil
		}
	}
}

func (s store) processOne(execute func(job) (job, error)) (bool, error) {
	var current job
	err := s.locked(func() error {
		interrupted, err := s.list("running")
		if err != nil {
			return err
		}
		for _, id := range interrupted {
			j, err := s.read("running", id)
			if err != nil {
				return err
			}
			j.Error = "worker interrupted; inspect retained work and retry explicitly"
			if err = s.write("running", j); err != nil {
				return err
			}
			if err = s.move("running", "failed", id); err != nil {
				return err
			}
		}
		pending, err := s.list("pending")
		if err != nil || len(pending) == 0 {
			return err
		}
		current, err = s.read("pending", pending[0])
		if err != nil {
			return err
		}
		current.Error = ""
		current.Entry = ""
		current.Work, err = os.MkdirTemp(filepath.Join(s.root, "work"), current.ID+"-")
		if err != nil {
			return err
		}
		if err = syncDirectory(filepath.Join(s.root, "work")); err != nil {
			return err
		}
		if err = s.write("pending", current); err != nil {
			return err
		}
		return s.move("pending", "running", current.ID)
	})
	if err != nil || current.ID == "" {
		return false, err
	}
	result, executionErr := execute(current)
	if result.ID != current.ID || result.Schema != 1 {
		return false, fmt.Errorf("worker returned a different job identity")
	}
	if executionErr == nil && !validID.MatchString(result.Entry) {
		executionErr = fmt.Errorf("preparation returned no valid boot entry")
	}
	state := "complete"
	if executionErr != nil {
		state = "failed"
		result.Error = executionErr.Error()
	}
	if err = s.locked(func() error {
		if err := s.write("running", result); err != nil {
			return err
		}
		return s.move("running", state, result.ID)
	}); err != nil {
		return false, err
	}
	fmt.Printf("Hardware preparation %s: %s\n", state, result.ID)
	// A recorded failure is terminal for this attempt, not a service restart loop.
	return true, nil
}

func prepare(j job) (job, error) {
	log, err := os.OpenFile(filepath.Join(j.Work, "prepare.log"), os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return j, err
	}
	defer log.Close()
	run := func(name string, args ...string) error {
		c := exec.Command(name, args...)
		c.Stdout, c.Stderr = log, log
		if err := c.Run(); err != nil {
			return fmt.Errorf("%s failed; see %s: %w", name, log.Name(), err)
		}
		return nil
	}
	resultFile := filepath.Join(j.Work, "stage.json")
	if err = run("oma-snap-boot-stage", "--set", j.ID, "--wait-lock=15m", "--result-file", resultFile); err != nil {
		return j, err
	}
	data, err := os.ReadFile(resultFile)
	if err != nil {
		return j, err
	}
	var result struct {
		Directory string `json:"directory"`
		Hardware  string `json:"hardware_set"`
		Entry     string `json:"boot_entry"`
	}
	if err = json.Unmarshal(data, &result); err != nil {
		return j, err
	}
	if result.Hardware != j.ID || !validID.MatchString(result.Entry) || filepath.Dir(result.Directory) != "/var/lib/oma-snap/staging" || filepath.Clean(result.Directory) != result.Directory {
		return j, fmt.Errorf("invalid staging completion record")
	}
	j.Entry = result.Entry
	data, err = os.ReadFile("/etc/oma-snap/esp-path")
	if err != nil {
		return j, err
	}
	esp := strings.TrimSpace(string(data))
	if err = run("oma-snap-boot-publish", "--stage", result.Directory, "--esp", esp, "--wait-lock=15m"); err != nil {
		return j, err
	}
	return j, log.Sync()
}
