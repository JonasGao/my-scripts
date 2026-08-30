# Store profile groups as comment metadata

Profile files remain sourceable Bash environment files, while an optional `# group: ...` comment stores the listing-only group. This keeps grouping out of the environment passed to Claude Code and preserves compatibility with existing profiles that have no metadata; alternatives that add a sourced variable would leak presentation data into runtime configuration.
