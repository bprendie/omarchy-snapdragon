package main

import "testing"

func TestRejectUnsafeInputs(t *testing.T) {
	for _, sample := range [][3]string{
		{"/", "/boot", "root=UUID=abcd"},
		{"/mnt/../", "/boot", "root=/dev/sda2"},
		{"mnt", "/boot", "root=/dev/sda2"},
		{"/mnt", "/boot/../../etc", "root=/dev/sda2"},
		{"/mnt", "/boot", "root=/dev/sda2; reboot"},
		{"/mnt", "/boot", "root=/dev/sda2\nreboot"},
		{"/mnt", "/boot", "quiet"},
	} {
		if validate(sample[0], sample[1], sample[2]) == nil {
			t.Fatalf("accepted unsafe input: %q", sample)
		}
	}
}

func TestEncryptedBtrfsCommandLine(t *testing.T) {
	if err := validate("/mnt", "/boot", "cryptdevice=UUID=1234-abcd:root root=/dev/mapper/root rootflags=subvol=@ rw"); err != nil {
		t.Fatal(err)
	}
}
