---
name: create-issue
description: This skill should be used when the user asks to "create an issue", "open a GitHub issue", "file an issue", "write up an issue", "make a ticket", or "draft an issue". Activates whenever the user wants to formally document a bug, feature request, or task as a GitHub issue — especially when success criteria or verification steps should be included.
argument-hint: "[issue title or brief description]"
allowed-tools:
  - Bash
  - Read
  - WebFetch
---

# Create Issue

This skill creates well-structured GitHub issues using a template that includes clear success criteria and verification steps, so reviewers and implementers know exactly what "done" looks like.

## Template

Every issue created with this skill follows this structure:

```markdown
## Summary

<!-- One paragraph. What is the problem or desired change, and why does it matter? -->

## Background / Context

<!-- Optional. Relevant constraints, prior decisions, related issues/PRs. -->

## Proposed Solution

<!-- What should be built or fixed? Be specific about scope. -->

## Success Criteria

A checklist of concrete, testable conditions. The issue is done when ALL of these are met:

- [ ] <!-- Observable behaviour or measurable outcome #1 -->
- [ ] <!-- Observable behaviour or measurable outcome #2 -->
- [ ] <!-- Edge case or constraint that must hold -->

## Verification Steps

Step-by-step instructions for a reviewer to confirm success criteria are met:

1. <!-- Setup / precondition -->
2. <!-- Action to take -->
3. <!-- Expected result -->
4. <!-- Repeat for each criterion -->

## Out of Scope

<!-- Explicitly list what this issue does NOT cover to prevent scope creep. -->

## Additional Context

<!-- Screenshots, logs, links, related issues. -->
```

## How to Use This Skill

### Step 1 — Gather information

Before drafting, collect:
- **What**: the specific problem or feature
- **Why**: the motivation or user impact
- **Where**: affected files, modules, or surfaces (if known)
- **Constraints**: deadlines, dependencies, non-goals

Ask the user clarifying questions if any of these are missing and the issue cannot be inferred from context.

### Step 2 — Draft the issue body

Fill every section of the template. Key rules:

- **Summary**: one paragraph, no bullet points. Lead with the problem, not the solution.
- **Success Criteria**: each item must be independently verifiable by a human. Avoid vague items like "works correctly" — write "clicking Save stores the value and shows a toast notification".
- **Verification Steps**: written as if for someone unfamiliar with the codebase. Include setup prerequisites (e.g. "run `npm run dev`", "log in as a user with role X").
- **Out of Scope**: always include at least one entry to signal intentional scoping.

### Step 3 — Pick labels and metadata

Based on issue content, suggest:

| Category       | Label to suggest        |
| -------------- | ----------------------- |
| Bug            | `bug`                   |
| New feature    | `enhancement`           |
| Documentation  | `documentation`         |
| Refactor       | `refactor`              |
| Performance    | `performance`           |
| Security       | `security`              |
| Good for new contributors | `good first issue` |

### Step 4 — Create the issue

Use `gh issue create` to file it:

```bash
gh issue create \
  --title "<title>" \
  --body "$(cat <<'EOF'
<issue body>
EOF
)" \
  --label "<label>"
```

If no GitHub remote exists or `gh` is not authenticated, output the final Markdown so the user can paste it manually.

### Step 5 — Confirm and share

`gh issue create` prints the issue URL on the last line of its output. Capture it and display it prominently to the user, e.g.:

```
Issue created: https://github.com/owner/repo/issues/42
```

If the URL is not printed (e.g. the command was piped), retrieve it with:

```bash
gh issue view --json url -q .url $(gh issue list --limit 1 --json number -q '.[0].number')
```

## Writing Good Success Criteria

Good success criteria are:

- **Specific**: "the API returns HTTP 201 with a `{ id }` body" not "the API works"
- **Observable**: a human can check them without reading source code
- **Binary**: either met or not — no partial credit
- **Complete**: cover the happy path, at least one error case, and any non-functional requirement (performance, accessibility, security)

### Examples

| Weak | Strong |
|------|--------|
| Works on mobile | The layout renders correctly at 375 px viewport width with no horizontal overflow |
| Error handling is improved | When the upstream API returns 5xx, the UI shows an error banner and does not crash |
| Tests pass | All existing unit tests pass; a new test covers the edge case described in the summary |
| Fast enough | P95 response time is ≤ 200 ms under 100 RPS load (measured in staging) |

## Writing Good Verification Steps

Verification steps should:

1. Start from a known state ("on a fresh branch", "with a clean database", "logged out")
2. Be numbered and sequential
3. State the **exact action** and the **expected result** for each step
4. Cover each success criterion by reference (or number)

Example:

```
1. Run `npm run dev` and open http://localhost:3000
2. Navigate to Settings → Notifications
3. Toggle "Email alerts" off and click Save
4. Expected: toast "Settings saved" appears; refreshing the page shows the toggle is still off
5. Check the network tab: the PATCH /api/settings request returned 200
```
