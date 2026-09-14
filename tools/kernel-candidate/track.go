package main

import "regexp"

var kernelRelease = regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-(generic|qcom-x1e)$`)

func (p policy) concept() bool { return p.MetaPackage == "linux-qcom-x1e" }

func supportedTrack(p policy) bool {
	if p.MetaPackage == "linux-generic" {
		return true
	}
	return p.concept() && p.Archive == "https://ppa.launchpadcontent.net/ubuntu-concept/x1e/ubuntu" &&
		p.Signer == "8818B03153EA3CE7BBEF3A2A07E5CB0286C3AF17"
}

func (p policy) suites() []string {
	if p.concept() {
		return []string{p.Release}
	}
	return []string{p.Release, p.Release + "-updates", p.Release + "-security"}
}

func (p policy) origin() string {
	if p.concept() {
		return "LP-PPA-ubuntu-concept-x1e"
	}
	return "Ubuntu"
}
