package main

import (
	"reflect"
	"testing"
)

const lockBefore = `{
  "nodes": {
    "root": {
      "inputs": {
        "nixpkgs": "nixpkgs",
        "home-manager": "home-manager",
        "follower": ["nixpkgs"]
      }
    },
    "nixpkgs": {
      "locked": {"rev": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "lastModified": 1751500800}
    },
    "home-manager": {
      "locked": {"rev": "cccccccccccccccccccccccccccccccccccccccc", "lastModified": 1751500800}
    }
  },
  "root": "root"
}`

const lockAfter = `{
  "nodes": {
    "root": {
      "inputs": {
        "nixpkgs": "nixpkgs",
        "home-manager": "home-manager",
        "follower": ["nixpkgs"]
      }
    },
    "nixpkgs": {
      "locked": {"rev": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "lastModified": 1751587200}
    },
    "home-manager": {
      "locked": {"rev": "cccccccccccccccccccccccccccccccccccccccc", "lastModified": 1751500800}
    }
  },
  "root": "root"
}`

func TestLockInputsSkipsFollows(t *testing.T) {
	inputs, err := LockInputs([]byte(lockBefore))
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := inputs["follower"]; ok {
		t.Error("follows references must be skipped")
	}
	if len(inputs) != 2 {
		t.Errorf("got %d inputs, want 2", len(inputs))
	}
}

func TestLockDiff(t *testing.T) {
	got, err := LockDiff([]byte(lockBefore), []byte(lockAfter))
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"nixpkgs: aaaaaaaaaaaa (2025-07-03) → bbbbbbbbbbbb (2025-07-04)"}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("LockDiff = %v, want %v", got, want)
	}
}

func TestLockDiffNoChanges(t *testing.T) {
	got, err := LockDiff([]byte(lockBefore), []byte(lockBefore))
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 0 {
		t.Errorf("LockDiff of identical locks = %v, want empty", got)
	}
}

func TestLockDiffAddedInput(t *testing.T) {
	after := `{
  "nodes": {
    "root": {"inputs": {"nixpkgs": "nixpkgs", "extra": "extra"}},
    "nixpkgs": {"locked": {"rev": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "lastModified": 1751500800}},
    "extra": {"locked": {"rev": "dddddddddddddddddddddddddddddddddddddddd", "lastModified": 1751587200}}
  },
  "root": "root"
}`
	before := `{
  "nodes": {
    "root": {"inputs": {"nixpkgs": "nixpkgs"}},
    "nixpkgs": {"locked": {"rev": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "lastModified": 1751500800}}
  },
  "root": "root"
}`
	got, err := LockDiff([]byte(before), []byte(after))
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"extra: ? (?) → dddddddddddd (2025-07-04)"}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("LockDiff = %v, want %v", got, want)
	}
}
