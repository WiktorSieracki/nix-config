package main

import (
	"reflect"
	"testing"
)

func gridMeta() map[string]FeatureMeta {
	return map[string]FeatureMeta{
		"git":    {Kind: "cli"},
		"fish":   {Kind: "cli"},
		"nix":    {Kind: "cli"},
		"vscode": {Kind: "gui"},
		"docker": {Kind: "service"},
		"wiktor": {Kind: "config"},
	}
}

func TestBuildGroupsKindOrderAndSorting(t *testing.T) {
	groups := BuildGroups(gridMeta(), []string{"stray"}, "")
	var kinds []string
	for _, g := range groups {
		kinds = append(kinds, g.Kind)
	}
	want := []string{"cli", "gui", "service", "config", "other"}
	if !reflect.DeepEqual(kinds, want) {
		t.Fatalf("group order = %v, want %v", kinds, want)
	}
	if !reflect.DeepEqual(groups[0].Items, []string{"fish", "git", "nix"}) {
		t.Errorf("cli items = %v, want alphabetical [fish git nix]", groups[0].Items)
	}
	if !reflect.DeepEqual(groups[4].Items, []string{"stray"}) {
		t.Errorf("file-only strays must stay visible, got %v", groups[4].Items)
	}
}

func TestBuildGroupsFilter(t *testing.T) {
	groups := BuildGroups(gridMeta(), nil, "GI")
	if len(groups) != 1 || !reflect.DeepEqual(groups[0].Items, []string{"git"}) {
		t.Errorf("filtered groups = %v, want just cli/[git]", groups)
	}
}

// Layout under test (2 columns, column-major, flat indices in parens):
//
//	cli             gui
//	a(0)  d(3)      x(5)  z(7)
//	b(1)  e(4)      y(6)
//	c(2)
func testGrid() Grid {
	return BuildGrid([]GridGroup{
		{Kind: "cli", Items: []string{"a", "b", "c", "d", "e"}},
		{Kind: "gui", Items: []string{"x", "y", "z"}},
	}, 2)
}

func TestGridLayout(t *testing.T) {
	g := testGrid()
	if g.Total != 8 {
		t.Fatalf("Total = %d, want 8", g.Total)
	}
	if g.Groups[0].Rows != 3 || g.Groups[1].Rows != 2 {
		t.Fatalf("rows = %d/%d, want 3/2", g.Groups[0].Rows, g.Groups[1].Rows)
	}
	if g.NameAt(0) != "a" || g.NameAt(3) != "d" || g.NameAt(5) != "x" || g.NameAt(7) != "z" {
		t.Error("NameAt: column-major flat order broken")
	}
	if g.NameAt(-1) != "" || g.NameAt(8) != "" {
		t.Error("NameAt out of range must return \"\"")
	}
}

func TestGridIndexOf(t *testing.T) {
	g := testGrid()
	if got := g.IndexOf("a"); got != 0 {
		t.Errorf("IndexOf(a) = %d, want 0", got)
	}
	if got := g.IndexOf("z"); got != 7 {
		t.Errorf("IndexOf(z) = %d, want 7", got)
	}
	if got := g.IndexOf("missing"); got != -1 {
		t.Errorf("IndexOf(missing) = %d, want -1", got)
	}
}

func TestGridDown(t *testing.T) {
	g := testGrid()
	if got := g.Down(0); g.NameAt(got) != "b" {
		t.Errorf("Down(a) = %s, want b (same column)", g.NameAt(got))
	}
	if got := g.Down(1); g.NameAt(got) != "c" {
		t.Errorf("Down(b) = %s, want c (same column)", g.NameAt(got))
	}
	if got := g.Down(2); g.NameAt(got) != "x" {
		t.Errorf("Down(c) crosses into gui col 0 row 0 = %s, want x", g.NameAt(got))
	}
	if got := g.Down(4); g.NameAt(got) != "z" {
		t.Errorf("Down(e) crosses into gui col 1 row 0 = %s, want z", g.NameAt(got))
	}
	if got := g.Down(6); got != 6 {
		t.Errorf("Down(y) at bottom of last group = %d, want stay 6", got)
	}
}

func TestGridUp(t *testing.T) {
	g := testGrid()
	if got := g.Up(1); g.NameAt(got) != "a" {
		t.Errorf("Up(b) = %s, want a", g.NameAt(got))
	}
	if got := g.Up(5); g.NameAt(got) != "c" {
		t.Errorf("Up(x) crosses into cli col 0 bottom = %s, want c", g.NameAt(got))
	}
	if got := g.Up(7); g.NameAt(got) != "e" {
		t.Errorf("Up(z) crosses into cli col 1 bottom = %s, want e", g.NameAt(got))
	}
	if got := g.Up(0); got != 0 {
		t.Errorf("Up(a) at top = %d, want stay 0", got)
	}
}

func TestGridLeftRight(t *testing.T) {
	g := testGrid()
	if got := g.Right(0); g.NameAt(got) != "d" {
		t.Errorf("Right(a) = %s, want d", g.NameAt(got))
	}
	if got := g.Right(2); g.NameAt(got) != "e" {
		t.Errorf("Right(b→row2, col1 shorter) clamps: got %s, want e", g.NameAt(got))
	}
	if got := g.Right(3); got != 3 {
		t.Errorf("Right(d) in last column = %d, want stay 3", got)
	}
	if got := g.Left(3); g.NameAt(got) != "a" {
		t.Errorf("Left(d) = %s, want a", g.NameAt(got))
	}
	if got := g.Left(0); got != 0 {
		t.Errorf("Left(a) in first column = %d, want stay 0", got)
	}
}

func TestGridSingleColumn(t *testing.T) {
	g := BuildGrid([]GridGroup{{Kind: "cli", Items: []string{"a", "b"}}}, 1)
	if g.Groups[0].Rows != 2 {
		t.Fatalf("rows = %d, want 2", g.Groups[0].Rows)
	}
	if g.Down(0) != 1 || g.Up(1) != 0 || g.Left(0) != 0 || g.Right(0) != 0 {
		t.Error("single-column navigation broken")
	}
}
