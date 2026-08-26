# Context

## Glossary

### Mapping

An association between an exact repository URL prefix and a local root directory.
The clone target is the mapping root plus URL segments remaining after the
longest matching prefix.

### Prefix

The host and zero or more repository path segments that identify a Mapping.
Prefixes are compared exactly and selected by longest match.

### Root directory

The local directory stored by a Mapping as the base for clone targets.

### Mapping management

The `gcr` command owns the user-facing operations for inspecting and removing
Mappings. `gcr mapping list` is human-oriented, while `gcr mapping remove`
accepts an exact Prefix. It does not provide a Mapping editing operation.

Mapping lists retain configuration order and show Prefix and Root columns. An
empty mapping configuration is a normal list result.

### Removal

The confirmed removal of exactly one existing Mapping. Removal shows the
Mapping before proceeding and may be explicitly made non-interactive with a
`--yes` option. It preserves the configuration file, its directory, and
unrelated Mapping sections.
