package main

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
)

func verifySet(dir string) error {
	return verifyPayload(filepath.Join(dir, "set.json"), filepath.Join(dir, "payload"), "")
}

func verifyInstalled(dir string) error {
	return verifyPayload(filepath.Join(dir, "set.json"), dir, "set.json")
}

func verifyPayload(manifestPath, payload, exclude string) error {
	var manifest struct {
		Schema  int     `json:"schema"`
		ID      string  `json:"id"`
		Release string  `json:"kernel_release"`
		Status  string  `json:"status"`
		Entries []entry `json:"entries"`
	}
	info, err := os.Lstat(manifestPath)
	if err != nil {
		return err
	}
	if !info.Mode().IsRegular() {
		return fmt.Errorf("manifest must be a regular file")
	}
	f, err := os.Open(manifestPath)
	if err != nil {
		return err
	}
	defer f.Close()
	decoder := json.NewDecoder(f)
	decoder.DisallowUnknownFields()
	if err = decoder.Decode(&manifest); err != nil {
		return err
	}
	if manifest.Schema != 1 || manifest.Status != "unvalidated" {
		return fmt.Errorf("unsupported manifest")
	}
	var provenance struct {
		Release string `json:"kernel_release"`
	}
	data, err := os.ReadFile(filepath.Join(payload, "provenance/extracted.json"))
	if err != nil {
		return err
	}
	if err = json.Unmarshal(data, &provenance); err != nil {
		return err
	}
	if manifest.Release != provenance.Release {
		return fmt.Errorf("kernel release differs from payload provenance")
	}
	actual, err := inventoryExcept(payload, exclude)
	if err != nil {
		return err
	}
	if !reflect.DeepEqual(manifest.Entries, actual) {
		return fmt.Errorf("payload inventory changed")
	}
	encoded, err := json.Marshal(actual)
	if err != nil {
		return err
	}
	if manifest.ID != fmt.Sprintf("%x", sha256.Sum256(encoded)) {
		return fmt.Errorf("payload identity mismatch")
	}
	fmt.Println("PASS: hardware payload matches its content identity")
	return nil
}
