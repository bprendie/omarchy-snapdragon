package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"
)

func run() error {
	enqueue := flag.Bool("enqueue", false, "queue hardware package targets from stdin")
	process := flag.Bool("process", false, "prepare one queued hardware set")
	retry := flag.String("retry", "", "retry a failed hardware set identity")
	refresh := flag.String("refresh", "", "prepare a new entry for a completed hardware set")
	status := flag.Bool("status", false, "show persistent job states as JSON lines")
	checkProvider := flag.Bool("check-provider-prepared", false, "require completed preparation for the installed provider")
	flag.Parse()
	modes := 0
	for _, active := range []bool{*enqueue, *process, *retry != "", *refresh != "", *status, *checkProvider} {
		if active {
			modes++
		}
	}
	if modes != 1 || flag.NArg() != 0 {
		return fmt.Errorf("choose --enqueue, --process, --retry ID, --refresh ID, --status or --check-provider-prepared")
	}
	s := store{root: "/var/lib/oma-snap/jobs"}
	if *status {
		if _, err := os.Stat(s.root); os.IsNotExist(err) {
			return nil
		} else if err != nil {
			return err
		}
		for _, state := range states {
			ids, err := s.list(state)
			if err != nil {
				return err
			}
			for _, id := range ids {
				j, err := s.read(state, id)
				if err != nil {
					return err
				}
				if err = json.NewEncoder(os.Stdout).Encode(struct {
					State string `json:"state"`
					Job   job    `json:"job"`
				}{state, j}); err != nil {
					return err
				}
			}
		}
		return nil
	}
	if os.Geteuid() != 0 {
		return fmt.Errorf("requires root")
	}
	if err := s.initialize(); err != nil {
		return err
	}
	if *checkProvider {
		return s.providerPrepared("/usr/share/oma-snap/kernel-provider/candidate.json")
	}
	if *process {
		return s.process(prepare)
	}
	if *retry != "" {
		return s.enqueue(*retry, true)
	}
	if *refresh != "" {
		return s.request(*refresh, "complete")
	}
	scanner := bufio.NewScanner(os.Stdin)
	var ids []string
	for scanner.Scan() {
		target := scanner.Text()
		id := strings.TrimPrefix(target, "oma-snap-set-")
		if id == target || !validID.MatchString(id) {
			return fmt.Errorf("unexpected hardware package target")
		}
		ids = append(ids, id)
	}
	if err := scanner.Err(); err != nil {
		return err
	}
	if len(ids) == 0 {
		return fmt.Errorf("no package targets")
	}
	for _, id := range ids {
		if err := s.enqueue(id, false); err != nil {
			return err
		}
	}
	return nil
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
