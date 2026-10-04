# Context

## Glossary

### Worktree

A linked working tree that `gwt` creates for a branch, in a dedicated directory
outside the Main repository. The Main repository is not itself a Worktree.

### Main repository

The primary checkout of a repository. `gwt` treats it as the canonical location
and as the Carry source. Every Worktree shares git history with the Main
repository.

### Carry list

The set of ignored, local-only configuration paths that the Main repository
seeds into each new Worktree. Entries name files or directories that git does
not track (for example local environment or editor settings), which a freshly
created Worktree would otherwise lack.

### Carry

Copying Carry list entries from the Carry source into a Worktree. Carrying runs
automatically when a Worktree is created. It only ever touches ignored,
local-only paths: it never overwrites files that git tracks.

### Carry source

The Main repository working tree — the single, canonical origin for Carried
files, regardless of which Worktree `gwt` was invoked from.

### Re-sync

Carrying the Carry list into an existing Worktree on demand, rather than at
creation time. A Re-sync adds entries that are missing and, unless forced,
leaves already-present files untouched.
