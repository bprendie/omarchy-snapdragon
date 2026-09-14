package main

import (
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestDepmodPreservesRetainedAndPassesOtherTargets(t *testing.T) {
	input := "usr/lib/modules/7.0.0-31-generic/\nusr/lib/modules/7.1.6-arch/\n"
	targets, err := depmodTargets(strings.NewReader(input), map[string]bool{"7.0.0-31-generic": true})
	if err != nil || !reflect.DeepEqual(targets, []string{"usr/lib/modules/7.1.6-arch/"}) {
		t.Fatal(targets, err)
	}
	for _, bad := range []string{"/usr/lib/modules/a/", "usr/lib/modules/../", "usr/lib/modules/a/extra", ""} {
		if _, err = depmodTargets(strings.NewReader(bad+"\n"), nil); err == nil {
			t.Fatal("accepted malformed hook target", bad)
		}
	}
}

func TestRetainedManifestAndMountpointValidation(t *testing.T) {
	root := t.TempDir()
	id := strings.Repeat("a", 64)
	dir := filepath.Join(root, id)
	if err := os.Mkdir(dir, 0755); err != nil {
		t.Fatal(err)
	}
	manifest := filepath.Join(dir, "set.json")
	data := fmt.Sprintf(`{"schema":1,"id":%q,"kernel_release":"7.0.0-31-generic"}`, id)
	if err := os.WriteFile(manifest, []byte(data), 0644); err != nil {
		t.Fatal(err)
	}
	releases, err := retainedReleases(root)
	if err != nil || !releases["7.0.0-31-generic"] {
		t.Fatal(releases, err)
	}
	lib := t.TempDir()
	for _, kind := range []string{"modules", "firmware"} {
		if err = os.Mkdir(filepath.Join(lib, kind), 0755); err != nil {
			t.Fatal(err)
		}
	}
	if err = ensureMountpoints(lib, releases); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(lib, "modules", "7.0.0-31-generic")
	if err = os.Remove(path); err != nil {
		t.Fatal(err)
	}
	if err = os.Symlink(t.TempDir(), path); err != nil {
		t.Fatal(err)
	}
	if err = ensureMountpoints(lib, releases); err == nil {
		t.Fatal("accepted substituted mountpoint")
	}
	if err = os.WriteFile(manifest, []byte(strings.Replace(data, id, strings.Repeat("b", 64), 1)), 0644); err != nil {
		t.Fatal(err)
	}
	if _, err = retainedReleases(root); err == nil {
		t.Fatal("accepted mismatched identity")
	}
}

func TestDanglingRetainedRootIsNotAbsence(t *testing.T) {
	path := filepath.Join(t.TempDir(), "sets")
	if _, err := retainedReleases(path); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink("/nonexistent-oma-test", path); err != nil {
		t.Fatal(err)
	}
	if _, err := retainedReleases(path); err == nil {
		t.Fatal("accepted dangling root")
	}
}
