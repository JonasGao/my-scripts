# Context

## Glossary

### Orphan branch

A local branch that has no upstream at all — it was either never pushed, or
created locally and forgotten. The tool's primary target.

### Gone branch

A local branch whose configured upstream used to exist on the remote but has
since been deleted there. Git reports the upstream track as `[gone]`.

`Gone` and `Orphan` both mean "the remote no longer has anything to do with
this branch", so both are清理 candidates. They differ only in whether an
upstream ref is still configured.

### Protected branch

A branch the tool refuses to delete, shown greyed-out and unselectable in the
web page and skipped in terminal mode. A branch is Protected when it is:

- a trunk branch (`master` / `main` / `develop`), or
- the currently checked-out branch, or
- carrying commits that exist on no remote (`unpushed`).

Protection is computed fresh on every run. It is a safety rail, not a
permission system — it does not survive an explicit `git branch -D`.

### Unpushed commits

Commits reachable from the branch but from no remote-tracking ref
(`git rev-list --count <branch> --not --remotes`). A branch with any Unpushed
commits is Protected, because deleting it would lose work that exists nowhere
else.

### Dirty worktree

A worktree whose `git status --porcelain` is non-empty. A branch attached to a
Dirty worktree is **not** Protected: it stays selectable, but is reported as a
Warning and offers a "查看改动" (view changes) view listing the modified files
and their diff.

### Warning

Advisory information attached to a selectable branch. Currently only Dirty
worktrees produce one. A Warning never blocks deletion — it exists so the user
can inspect what will be discarded before confirming.

### Changes view

The per-branch page (`/diff?branch=<name>`) showing a Dirty branch's changed
files and their diff, including the content of untracked files. Read-only, and
available only in web mode.

### Worktree mapping

The association from branch to worktree path produced by
`git worktree list --porcelain`. Each branch has at most one worktree; the
main checkout is itself a worktree, so a branch checked out there maps to the
main repository path.

A branch may have no worktree at all (it is not checked out anywhere). Absence
of a worktree is not Protection — such branches are deleted with
`git branch -D` alone.

### Batch

The set of branches the user selected in the web page and submitted in one
request. A Batch is executed item by item and the page reports each result.
A failure on one item does not stop the rest of the Batch.

### One-shot session

A web-mode run serves exactly one Batch. After the POST is handled the process
prints the same summary to the terminal, then exits, releasing the port. A
session that never receives a POST waits indefinitely.

### Quit

An explicit, user-initiated end to the session that deletes nothing. The page's
"退出" button posts to `/quit`, which marks the session done and lets the
process exit. Any checkbox selections are discarded — Quit is the "cancel"
counterpart to a Batch, not a partial apply.

### Orphan scan

The full pass over `refs/heads/` that produces every branch's status,
upstream tracking, worktree mapping, commit metadata, and Protection reason.
The scan runs once at startup; the web page renders that single snapshot, so
deleting a branch does not refresh the table.

## Invariants

- `master` / `main` / `develop` are never deletable through the tool.
- The currently checked-out branch is never deletable through the tool.
- A Warning never blocks deletion; only Protection does.
- Every git invocation uses an argument list, never a shell string.
- All values interpolated into HTML are escaped.
- A Batch never partially applies a single item: a branch either has both its
  worktree and its ref removed, or a failure is reported for it.
