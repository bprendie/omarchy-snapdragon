package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

type artifact struct {
	Name         string `json:"package"`
	Version      string `json:"version"`
	Architecture string `json:"architecture"`
	Suite        string `json:"suite"`
	Filename     string `json:"filename"`
	SHA256       string `json:"sha256"`
	Size         int64  `json:"size"`
	Depends      string `json:"depends"`
}
type candidate struct {
	Schema        int          `json:"schema"`
	Status        string       `json:"status"`
	Created       time.Time    `json:"created_at"`
	Policy        policy       `json:"policy"`
	KernelRelease string       `json:"kernel_release"`
	Repositories  []repository `json:"repositories"`
	Artifacts     []artifact   `json:"artifacts"`
	Downloaded    bool         `json:"downloaded"`
}

func fileHash(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err = io.Copy(h, f); err != nil {
		return "", err
	}
	return fmt.Sprintf("%x", h.Sum(nil)), nil
}

func run() error {
	policyFile := flag.String("policy", "", "track policy JSON")
	output := flag.String("output", "", "new candidate directory (must not exist)")
	verify := flag.String("verify", "", "reverify a saved candidate offline against --policy")
	extract := flag.String("extract", "", "extract a verified candidate into a new build directory")
	download := flag.Bool("download", false, "download verified payloads as well as metadata")
	flag.Parse()
	if *policyFile == "" || (*output == "" && *verify == "") || (*output != "" && *verify != "") || (*extract != "" && *verify == "") || flag.NArg() != 0 {
		return fmt.Errorf("specify --policy and --output")
	}
	data, err := os.Open(*policyFile)
	if err != nil {
		return err
	}
	defer data.Close()
	var p policy
	decoder := json.NewDecoder(data)
	decoder.DisallowUnknownFields()
	if err = decoder.Decode(&p); err != nil {
		return err
	}
	if !regexp.MustCompile(`^[a-z]+$`).MatchString(p.Release) || p.Architecture != "arm64" || p.MetaPackage != "linux-generic" || p.MaxAge < 1 || p.MaxAge > 168 || !regexp.MustCompile(`^[A-F0-9]{40}$`).MatchString(p.Signer) {
		return fmt.Errorf("unsupported track policy")
	}
	if _, err = archiveURL(p.Archive, "dists/"+p.Release+"/InRelease"); err != nil {
		return err
	}
	if *verify != "" {
		c, err := verifyCandidate(p, *verify)
		if err != nil {
			return err
		}
		if *extract != "" {
			return extractCandidate(c, *verify, *extract)
		}
		fmt.Println("PASS: saved candidate authenticated and all artifacts verified")
		return nil
	}
	if err = os.Mkdir(*output, 0755); err != nil {
		return err
	}
	result := candidate{Schema: 1, Status: candidateStatus(p), Created: time.Now().UTC(), Policy: p, Downloaded: *download}
	var records []record
	for _, suite := range []string{p.Release, p.Release + "-updates", p.Release + "-security"} {
		fmt.Fprintln(os.Stderr, "Verify", suite)
		dir := filepath.Join(*output, suite)
		if err = os.Mkdir(dir, 0755); err != nil {
			return err
		}
		rows, evidence, err := loadIndex(p, suite, dir, false)
		if err != nil {
			return fmt.Errorf("%s: %w", suite, err)
		}
		records = append(records, rows...)
		result.Repositories = append(result.Repositories, evidence)
	}
	selected, release, err := resolvePolicy(records, p)
	if err != nil {
		return err
	}
	result.KernelRelease = release
	if err = os.Mkdir(filepath.Join(*output, "artifacts"), 0755); err != nil {
		return err
	}
	for _, r := range selected {
		f := r.Fields
		size, err := strconv.ParseInt(f["Size"], 10, 64)
		if err != nil || size <= 0 || size > 2<<30 {
			return fmt.Errorf("invalid package size")
		}
		hash, err := hex.DecodeString(f["SHA256"])
		if err != nil || len(hash) != 32 {
			return fmt.Errorf("invalid package hash")
		}
		if !strings.HasPrefix(f["Filename"], "pool/") {
			return fmt.Errorf("unexpected package path")
		}
		if _, err = archiveURL(p.Archive, f["Filename"]); err != nil {
			return err
		}
		a := artifact{f["Package"], f["Version"], f["Architecture"], r.Suite, f["Filename"], f["SHA256"], size, f["Depends"]}
		result.Artifacts = append(result.Artifacts, a)
		if *download {
			fmt.Fprintln(os.Stderr, "Download", a.Name, a.Version)
			if err = fetch(p.Archive, a.Filename, filepath.Join(*output, "artifacts", filepath.Base(a.Filename)), a.SHA256, a.Size, 2<<30); err != nil {
				return err
			}
		}
	}
	encoded, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		return err
	}
	if err = os.WriteFile(filepath.Join(*output, "candidate.json"), append(encoded, '\n'), 0644); err != nil {
		return err
	}
	fmt.Println(string(encoded))
	return nil
}
func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
