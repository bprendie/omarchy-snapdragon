package main

import (
	"context"
	"crypto/sha256"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path"
	"strings"
	"time"
)

func archiveURL(base, rel string) (string, error) {
	u, err := url.Parse(base)
	if err != nil {
		return "", err
	}
	if u.Scheme != "https" || u.Host == "" || u.User != nil || u.RawQuery != "" || u.Fragment != "" {
		return "", fmt.Errorf("archive must be plain HTTPS URL")
	}
	if strings.HasPrefix(rel, "/") || path.Clean(rel) != rel || strings.Contains(rel, "..") || strings.ContainsAny(rel, "?#\\") {
		return "", fmt.Errorf("unsafe archive path %q", rel)
	}
	return strings.TrimRight(base, "/") + "/" + rel, nil
}

func fetch(base, rel, dest, want string, size, max int64) error {
	address, err := archiveURL(base, rel)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Minute)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, "GET", address, nil)
	if err != nil {
		return err
	}
	client := &http.Client{CheckRedirect: func(req *http.Request, via []*http.Request) error {
		if len(via) > 5 || req.URL.Scheme != "https" {
			return fmt.Errorf("unsafe redirect")
		}
		return nil
	}}
	res, err := client.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	if res.StatusCode != 200 {
		return fmt.Errorf("GET %s: %s", address, res.Status)
	}
	f, err := os.OpenFile(dest+".part", os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	defer os.Remove(dest + ".part")
	h := sha256.New()
	n, err := io.Copy(io.MultiWriter(f, h), io.LimitReader(res.Body, max+1))
	closeErr := f.Close()
	if err != nil {
		return err
	}
	if closeErr != nil {
		return closeErr
	}
	if n > max || (size > 0 && n != size) {
		return fmt.Errorf("size mismatch for %s: %d", rel, n)
	}
	if want != "" && fmt.Sprintf("%x", h.Sum(nil)) != want {
		return fmt.Errorf("SHA256 mismatch for %s", rel)
	}
	return os.Rename(dest+".part", dest)
}
