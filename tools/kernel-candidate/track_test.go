package main

import (
	"strings"
	"testing"
	"time"
)

func TestConceptClosure(t *testing.T) {
	rows := fixture()
	for i := range rows {
		f := rows[i].Fields
		f["Version"] = "7.2.0-18.31"
		for _, key := range []string{"Package", "Depends"} {
			v := strings.ReplaceAll(f[key], "7.0.0-31", "7.2.0-18")
			v = strings.ReplaceAll(v, "generic", "qcom-x1e")
			v = strings.ReplaceAll(v, "linux-headers-7.2.0-18,", "linux-qcom-x1e-headers-7.2.0-18,")
			if v == "linux-headers-7.2.0-18" {
				v = "linux-qcom-x1e-headers-7.2.0-18"
			}
			f[key] = v
		}
	}
	got, release, err := closure(rows, "linux-qcom-x1e")
	if err != nil || release != "7.2.0-18-qcom-x1e" || len(got) != 7 {
		t.Fatal(release, got, err)
	}
	rows[6].Fields["Version"] = "wrong"
	if _, _, err := closure(rows, "linux-qcom-x1e"); err == nil {
		t.Fatal("accepted mismatched common headers")
	}
}

func TestConceptTrustAndFreshness(t *testing.T) {
	p := policy{MetaPackage: "linux-qcom-x1e", Archive: "https://ppa.launchpadcontent.net/ubuntu-concept/x1e/ubuntu", Signer: "8818B03153EA3CE7BBEF3A2A07E5CB0286C3AF17", Release: "resolute", MaxAge: 168}
	if !supportedTrack(p) || len(p.suites()) != 1 {
		t.Fatal(p)
	}
	bad := p
	bad.Signer = strings.Repeat("A", 40)
	if supportedTrack(bad) {
		t.Fatal("accepted wrong PPA signer")
	}
	bad = p
	bad.Archive = "https://example.com/ubuntu"
	if supportedTrack(bad) {
		t.Fatal("accepted wrong PPA URL")
	}
	now := time.Now()
	f := fields{"Origin": p.origin(), "Suite": "resolute", "Codename": "resolute", "Date": now.Add(-time.Hour).Format(time.RFC1123)}
	if err := checkRelease(p, "resolute", f, now); err != nil {
		t.Fatal(err)
	}
	f["Date"] = now.Add(-8 * 24 * time.Hour).Format(time.RFC1123)
	if err := checkRelease(p, "resolute", f, now); err == nil {
		t.Fatal("PPA inherited annual base-suite freshness")
	}
}
