package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRunningAndPublishedSetsProtected(t *testing.T) {
	root := t.TempDir()
	entries, running := filepath.Join(root, "entries"), filepath.Join(root, "running")
	a, b, c := strings.Repeat("a", 64), strings.Repeat("b", 64), strings.Repeat("c", 64)
	if err := os.MkdirAll(filepath.Join(entries, c), 0755); err != nil {
		t.Fatal(err)
	}
	manifest := `{"schema":1,"boot_entry":"` + c + `","hardware_set":"` + b + `"}`
	if err := os.WriteFile(filepath.Join(entries, c, "entry.json"), []byte(manifest), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(running, []byte(a+"\n"), 0644); err != nil {
		t.Fatal(err)
	}
	protected, err := protectedSets(entries, running)
	if err != nil {
		t.Fatal(err)
	}
	for _, id := range []string{a, b} {
		if err = checkTargets(strings.NewReader("oma-snap-set-"+id+"\n"), protected); err == nil {
			t.Fatal("protected package accepted")
		}
	}
	if err = checkTargets(strings.NewReader("oma-snap-set-"+c+"\n"), protected); err != nil {
		t.Fatalf("unused set rejected: %v", err)
	}
}

func TestMissingOrSubstitutedStateFails(t *testing.T) {
	root := t.TempDir()
	entries, running := filepath.Join(root, "entries"), filepath.Join(root, "running")
	if _, err := protectedSets(entries, running); err == nil {
		t.Fatal("missing entries accepted")
	}
	if err := os.Mkdir(entries, 0755); err != nil {
		t.Fatal(err)
	}
	link := filepath.Join(root, "linked-entries")
	if err := os.Symlink(entries, link); err != nil {
		t.Fatal(err)
	}
	if _, err := protectedSets(link, running); err == nil {
		t.Fatal("symlink accepted")
	}
	if err := os.WriteFile(running, []byte("malformed"), 0644); err != nil {
		t.Fatal(err)
	}
	if _, err := protectedSets(entries, running); err == nil {
		t.Fatal("malformed runtime identity accepted")
	}
}

func TestUnexpectedTargetsFail(t *testing.T) {
	for _, input := range []string{"", "linux\n", "oma-snap-set-invalid\n"} {
		if err := checkTargets(strings.NewReader(input), map[string]bool{}); err == nil {
			t.Fatalf("accepted %q", input)
		}
	}
}
