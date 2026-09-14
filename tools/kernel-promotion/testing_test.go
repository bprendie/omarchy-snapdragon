package main

import "testing"

func TestExplicitTestingDeferrals(t *testing.T) {
	a, dir, archive := fixture(t)
	kept := []evidence{}
	a.DeferredTests = map[string]string{}
	for _, e := range a.Evidence {
		if deferrableTestingCheck(e.Kind) {
			a.DeferredTests[e.Kind] = "Owner requests experimental physical-test candidate"
		} else {
			kept = append(kept, e)
		}
	}
	a.Evidence = kept
	a.Hardware["asus-ux3607oa"] = "untested"
	if err := a.verify(dir, archive, 1); err != nil {
		t.Fatal(err)
	}
	a.Channel = "stable"
	a.Hardware["t14s"], a.Hardware["hp-g1q"] = "validated", "validated"
	if err := a.verify(dir, archive, 1); err == nil {
		t.Fatal("stable accepted deferred checks")
	}
	a.Channel = "testing"
	a.DeferredTests["source-verification"] = "not allowed"
	a.Evidence = a.Evidence[1:]
	if err := a.verify(dir, archive, 1); err == nil {
		t.Fatal("accepted missing mandatory evidence")
	}
}
