# Store profile validity as display-only metadata

Persist each profile's validity flag as a `# valid: true|false` comment, defaulting missing or malformed values to `true`; the flag is used only for `list` and `view` display and never blocks `run`, `load`, or default-profile selection. Keeping it as comment metadata preserves the sourceable Bash environment format and avoids leaking presentation state into Claude Code's runtime environment.
