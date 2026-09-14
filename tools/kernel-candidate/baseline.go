package main

import (
	"fmt"
	"regexp"
)

func candidateStatus(p policy) string {
	if p.TestRelease != "" {
		return "rollback-test"
	}
	return "unvalidated"
}

// An external test policy may select an older, still authenticated ABI. Normal
// discovery continues to resolve the latest meta-package and its full closure.
func resolvePolicy(records []record, p policy) ([]record, string, error) {
	latest, release, err := closure(records, p.MetaPackage)
	if err != nil || p.TestRelease == "" {
		return latest, release, err
	}
	if !regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-(generic|qcom-x1e)$`).MatchString(p.TestRelease) {
		return nil, "", fmt.Errorf("invalid rollback test release")
	}
	image, err := selectRecord(records, "linux-image-"+p.TestRelease, "")
	if err != nil {
		return nil, "", err
	}
	current, err := selectRecord(latest, "linux-image-"+release, "")
	if err != nil {
		return nil, "", err
	}
	older, err := newer(current.Fields["Version"], image.Fields["Version"])
	if err != nil || !older {
		return nil, "", fmt.Errorf("rollback test release must precede the current signed candidate")
	}
	headers, err := selectRecord(records, "linux-headers-"+p.TestRelease, image.Fields["Version"])
	if err != nil {
		return nil, "", err
	}
	selected, resolved, err := closureRoots(records, []record{image, headers})
	if err != nil {
		return nil, "", err
	}
	if resolved != p.TestRelease {
		return nil, "", fmt.Errorf("rollback dependency closure selected another ABI")
	}
	return selected, resolved, nil
}
