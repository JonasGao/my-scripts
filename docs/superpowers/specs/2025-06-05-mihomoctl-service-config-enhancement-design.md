# Mihomoctl Service and Config Enhancement Design

**Date:** 2025-06-05  
**Author:** OpenCode AI  
**Status:** Approved  

## Overview

Enhance the mihomoctl management script to:
1. Support configurable config directory for systemd service (using `-d` parameter)
2. Add interactive menu for config selection when no argument provided

## Design Goals

- Provide flexibility for custom config directories instead of hardcoded `/etc/mihomo`
- Improve user experience with interactive config selection menu
- Maintain backward compatibility with existing usage patterns
- Keep implementation simple and maintainable

## Requirements

### Requirement 1: Configurable Config Directory for Service

**Current Behavior:**
- Service uses `-f /etc/mihomo/config.yaml` (single file mode)
- Config directory is hardcoded as `/etc/mihomo`
- No way to customize config location during installation

**Desired Behavior:**
- Service uses `-d <config-dir>` (directory mode)
- Support `--config-dir` parameter during installation
- Default config directory remains `/etc/mihomo`
- Service ExecStart hardcodes the chosen directory path

**User Story:**
```bash
# Default installation
mihomoctl install
# → ExecStart=/usr/local/bin/mihomo -d /etc/mihomo

# Custom config directory
mihomoctl install --config-dir /custom/path
# → ExecStart=/usr/local/bin/mihomo -d /custom/path
```

### Requirement 2: Interactive Config Selection Menu

**Current Behavior:**
- `config select` requires explicit config name or path argument
- No guidance when user forgets to provide argument
- Users must remember exact config names

**Desired Behavior:**
- Smart mode: with argument → direct apply, no argument → interactive menu
- Interactive menu shows detailed info: index, type, filename, size, timestamp
- Supports both numeric selection and direct file path input
- Clear error messages when no configs available

**User Story:**
```bash
# Direct selection (existing behavior preserved)
mihomoctl config select myconfig.yaml

# Interactive menu (new behavior)
mihomoctl config select

# Menu output:
Available configs:

 1) [manual ] myconfig.yaml (2.5K, 2025-06-05)
 2) [profile] mysub-20250605-143022.yaml (15K, 2025-06-05)

Or enter file path directly

Select config [1-2] or path: _
```

## Technical Design

### Component 1: Service Parameter Enhancement

**Location:** `do_install()` function (line 161-276)

**Changes:**

1. Add parameter parsing at function start:
   ```bash
   local config_dir="/etc/mihomo"
   local force_download=0
   
   while [[ $# -gt 0 ]]; do
       case "$1" in
           -f|--force)
               force_download=1
               shift
               ;;
           --config-dir)
               config_dir="$2"
               shift 2
               ;;
           *)
               shift
               ;;
       esac
   done
   
   # Save config directory preference for other commands
   if [ "$config_dir" != "/etc/mihomo" ]; then
       mkdir -p ~/.config/mihomo
       echo "$config_dir" > ~/.config/mihomo/config-dir.conf
   fi
   ```

2. Add helper function to read config directory preference:
   ```bash
   get_config_dir() {
       local default_dir="/etc/mihomo"
       local config_file="$HOME/.config/mihomo/config-dir.conf"
       
       if [ -f "$config_file" ]; then
           local saved_dir=$(cat "$config_file")
           if [ -n "$saved_dir" ] && [ -d "$saved_dir" ]; then
               echo "$saved_dir"
               return
           fi
       fi
       echo "$default_dir"
   }
   ```

3. Update script-level CONFIG_DIR initialization:
   ```bash
   CONFIG_DIR=$(get_config_dir)
   ```

2. Replace hardcoded CONFIG_DIR with config_dir variable throughout function

3. Update systemd service template:
   ```bash
   ExecStart=${INSTALL_DIR}/mihomo -d ${config_dir}
   ```

4. Remove `-f` parameter entirely (was line 261)

**Implementation Notes:**
- When custom config directory is specified, save it to a configuration file
- All commands read config directory from saved configuration (or use default)
- Ensures consistency across all mihomoctl commands
- Service file uses absolute path, no environment variables
- Config directory preference file: `~/.config/mihomo/config-dir.conf`

**Configuration Persistence:**
- Preference file location: `$HOME/.config/mihomo/config-dir.conf`
- Written during installation if custom directory specified
- Read by all commands at startup to set CONFIG_DIR
- If preference file missing or directory invalid, fallback to `/etc/mihomo`
- Users can manually edit the file to change config directory
- Remove preference file to restore default behavior

### Component 2: Interactive Config Selection

**Location:** `do_config_select()` function (line 565-647)

**Changes:**

1. Add smart mode detection at function start:
   ```bash
   do_config_select() {
       local target="${1:-}"
       
       if [ -z "$target" ]; then
           do_config_select_interactive
           return 0
       fi
       
       # Existing logic continues...
   }
   ```

2. Create new function `do_config_select_interactive()`:
   - Collect manual configs from `$MANUAL_CONFIG_DIR/*.yaml`
   - Collect downloaded profiles from `$CONFIG_REPO_DIR/*.yaml`
   - Display numbered list with detailed info
   - Read user selection (number or path)
   - Call `apply_config()` with selected file

3. Extract config application logic to `apply_config()`:
   - Takes profile_path as argument
   - Contains all the backup, copy, validate, restart logic
   - Called by both interactive and direct modes
   - Line 609-646 content moves here

**Menu Display Format:**
```
Available configs:

 1) [manual ] myconfig.yaml (2.5K, 2025-06-05)
 2) [profile] mysub-20250605-143022.yaml (15K, 2025-06-05)

Or enter file path directly

Select config [1-2] or path: _
```

**Format Details:**
- Index: Number with left padding for alignment (2-width)
- Type: 7-character field (`manual` or `profile`)
- Filename: basename of config file
- Size: human-readable size from `du -h`
- Timestamp: date portion from `stat -c %y`

### Component 3: Helper Function Refactoring

**New Functions:**

1. `get_config_dir()` - Read saved config directory preference
2. `do_config_select_interactive()` - Interactive menu logic
3. `apply_config()` - Config application logic (shared)

**Modified Functions:**

1. `do_config_select()` - Add smart mode detection
2. `do_install()` - Add --config-dir parameter support

**No Changes:**

- All other functions remain unchanged
- `do_config_list_configs()` keeps existing behavior
- Config directory constants at script level unchanged

## Implementation Approach

### Phase 1: Service Parameter Enhancement

1. Add parameter parsing to `do_install()`
2. Replace systemd ExecStart template
3. Test with default and custom config directories
4. Verify service starts correctly with `-d` parameter

### Phase 2: Interactive Config Selection

1. Add smart mode check to `do_config_select()`
2. Implement `do_config_select_interactive()` function
3. Extract `apply_config()` function
4. Test both interactive and direct modes
5. Verify menu display format matches specification

### Phase 3: Testing and Validation

1. Test default installation flow
2. Test custom config directory installation
3. Test interactive menu with various config scenarios
4. Test direct config selection (backward compatibility)
5. Test service restart after config change

## Error Handling

**Service Installation:**
- Create config directory if it doesn't exist
- Validate mihomo binary successfully installed
- Handle service daemon-reload errors gracefully
- Save config directory preference to user config file

**Interactive Selection:**
- No configs available → clear error message with guidance
- Invalid numeric selection → error and retry
- Invalid file path → error and guidance
- Config validation failure → restore backup and error

**Backward Compatibility:**
- Existing direct selection usage preserved
- Default behavior unchanged (uses /etc/mihomo)
- Service file format compatible with systemd

## Security Considerations

- Config directory must be accessible by mihomo service
- Service runs with system privileges (requires root for install)
- No secrets in command-line arguments
- Config files readable by service user

## Testing Strategy

**Unit Tests:**
- Parameter parsing logic
- Config collection logic
- Menu display formatting
- Selection validation

**Integration Tests:**
- Full installation flow with default directory
- Installation with custom directory
- Interactive selection workflow
- Service start/restart with new configs

**Edge Cases:**
- Empty config directories
- Invalid selection numbers
- Non-existent file paths
- Permission errors

## Documentation Updates

**Help Text:**
- Add `--config-dir` option to install command help
- Update config select description to mention interactive mode
- Add examples for both features

**Usage Examples:**
```bash
# Custom config directory installation
mihomoctl install --config-dir /opt/mihomo-config

# Interactive config selection
mihomoctl config select

# Direct config selection (preserved)
mihomoctl config select myconfig.yaml
```

## Impact Analysis

**Affected Components:**
- `get_config_dir()` helper function - new function to read saved preference
- CONFIG_DIR initialization - dynamic instead of hardcoded
- `do_install()` function - parameter parsing, service template, save preference
- `do_config_select()` function - smart mode logic
- Service file template - ExecStart parameter change

**Unaffected Components:**
- All other config management functions
- UI management functions
- Service management (start/stop/restart) functions
- Uninstall function

**User Impact:**
- New installation behavior (uses `-d` parameter)
- New interactive selection experience
- Existing workflows preserved (backward compatible)
- No breaking changes to command syntax

## Success Criteria

1. Service successfully starts with `-d` parameter
2. Custom config directories work correctly
3. Interactive menu displays correct information
4. Both selection modes work as specified
5. Backward compatibility maintained
6. No regression in existing functionality
7. Clear error messages for edge cases

## References

- Mihomo documentation on `-d` parameter behavior
- Bash `select` command alternatives for interactive menus
- Systemd service configuration best practices
- FHS (Filesystem Hierarchy Standard) for config locations