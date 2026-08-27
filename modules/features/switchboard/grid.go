package main

// Multi-column feature grid: layout (grouped by kind, alphabetical within a
// group, column-major fill like `ls`) and vim-style navigation. Pure logic,
// tested in grid_test.go.

import (
	"sort"
	"strings"
)

// kindOrder is the on-screen order of the kind group headers.
var kindOrder = []string{"cli", "gui", "service", "config"}

// otherKind groups features present in features.json but absent from
// featureMeta (file-only strays are kept visible, as in the Python version).
const otherKind = "other"

type GridGroup struct {
	Kind  string
	Items []string // alphabetical
	Rows  int      // rows of this group's column-major layout
}

type Grid struct {
	Groups []GridGroup
	Total  int
	starts []int // flat index of each group's first item
}

// BuildGroups groups the visible feature names by kind. The catalog is
// featureMeta plus any file-only strays from `enabled`; filter is a
// case-insensitive substring match.
func BuildGroups(meta map[string]FeatureMeta, enabled []string, filter string) []GridGroup {
	all := map[string]bool{}
	for name := range meta {
		all[name] = true
	}
	for _, name := range enabled {
		all[name] = true
	}

	f := strings.ToLower(strings.TrimSpace(filter))
	byKind := map[string][]string{}
	for name := range all {
		if f != "" && !strings.Contains(strings.ToLower(name), f) {
			continue
		}
		kind := otherKind
		if m, ok := meta[name]; ok && m.Kind != "" {
			kind = m.Kind
		}
		byKind[kind] = append(byKind[kind], name)
	}

	order := append([]string(nil), kindOrder...)
	var extra []string
	for k := range byKind {
		if k != otherKind && !contains(order, k) {
			extra = append(extra, k)
		}
	}
	sort.Strings(extra)
	order = append(order, extra...)
	order = append(order, otherKind)

	var out []GridGroup
	for _, k := range order {
		items := byKind[k]
		if len(items) == 0 {
			continue
		}
		sort.Strings(items)
		out = append(out, GridGroup{Kind: k, Items: items})
	}
	return out
}

// BuildGrid lays the groups out into at most cols columns (column-major).
func BuildGrid(groups []GridGroup, cols int) Grid {
	if cols < 1 {
		cols = 1
	}
	g := Grid{Groups: groups}
	for i := range g.Groups {
		n := len(g.Groups[i].Items)
		g.Groups[i].Rows = (n + cols - 1) / cols
		g.starts = append(g.starts, g.Total)
		g.Total += n
	}
	return g
}

// Start returns the flat index of the group's first item.
func (g Grid) Start(gi int) int { return g.starts[gi] }

// IndexOf returns the flat index of a feature name (-1 when absent).
func (g Grid) IndexOf(name string) int {
	for gi, grp := range g.Groups {
		for li, item := range grp.Items {
			if item == name {
				return g.starts[gi] + li
			}
		}
	}
	return -1
}

// NameAt returns the feature name at a flat index ("" when out of range).
func (g Grid) NameAt(idx int) string {
	gi, li, ok := g.locate(idx)
	if !ok {
		return ""
	}
	return g.Groups[gi].Items[li]
}

func (g Grid) locate(idx int) (gi, li int, ok bool) {
	if idx < 0 || idx >= g.Total {
		return 0, 0, false
	}
	for i := range g.Groups {
		if idx < g.starts[i]+len(g.Groups[i].Items) {
			return i, idx - g.starts[i], true
		}
	}
	return 0, 0, false
}

func occupiedCols(grp GridGroup) int {
	if grp.Rows == 0 {
		return 0
	}
	return (len(grp.Items) + grp.Rows - 1) / grp.Rows
}

// Down moves the cursor one row down, crossing into the next group's first
// row (same column, clamped) at a group boundary.
func (g Grid) Down(idx int) int {
	gi, li, ok := g.locate(idx)
	if !ok {
		return idx
	}
	grp := g.Groups[gi]
	if li+1 < len(grp.Items) && (li+1)%grp.Rows != 0 {
		return idx + 1 // next row, same column
	}
	if gi+1 < len(g.Groups) {
		ng := g.Groups[gi+1]
		col := min(li/grp.Rows, occupiedCols(ng)-1)
		return g.starts[gi+1] + col*ng.Rows
	}
	return idx
}

// Up moves the cursor one row up, crossing into the previous group's last
// row (same column, clamped) at a group boundary.
func (g Grid) Up(idx int) int {
	gi, li, ok := g.locate(idx)
	if !ok {
		return idx
	}
	grp := g.Groups[gi]
	if li%grp.Rows != 0 {
		return idx - 1 // previous row, same column
	}
	if gi > 0 {
		pg := g.Groups[gi-1]
		col := min(li/grp.Rows, occupiedCols(pg)-1)
		last := min((col+1)*pg.Rows, len(pg.Items)) - 1
		return g.starts[gi-1] + last
	}
	return idx
}

// Right moves one column right within the group, clamping the row when the
// target column is shorter.
func (g Grid) Right(idx int) int {
	gi, li, ok := g.locate(idx)
	if !ok {
		return idx
	}
	grp := g.Groups[gi]
	col, row := li/grp.Rows, li%grp.Rows
	if col+1 < occupiedCols(grp) {
		return g.starts[gi] + min((col+1)*grp.Rows+row, len(grp.Items)-1)
	}
	return idx
}

// Left moves one column left within the group (earlier columns are always
// full, so the same row always exists).
func (g Grid) Left(idx int) int {
	gi, li, ok := g.locate(idx)
	if !ok {
		return idx
	}
	grp := g.Groups[gi]
	col, row := li/grp.Rows, li%grp.Rows
	if col > 0 {
		return g.starts[gi] + (col-1)*grp.Rows + row
	}
	return idx
}

func contains(list []string, s string) bool {
	for _, x := range list {
		if x == s {
			return true
		}
	}
	return false
}
