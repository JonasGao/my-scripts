#!/bin/bash

set -euo pipefail

test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
script_path=$(cd -- "$test_dir/.." && pwd)/list-zellij-panes

run_cli_for_pane() {
    local pane_id=$1
    shift

    PATH="$test_dir/bin:$PATH" \
        ZELLIJ_PANE_ID="$pane_id" \
        ZELLIJ_TEST_PANES_FILE="$test_dir/fixtures/panes.json" \
        ZELLIJ_TEST_TABS_FILE="$test_dir/fixtures/tabs.json" \
        "$script_path" "$@"
}

run_cli() {
    run_cli_for_pane 10 "$@"
}

assert_contains() {
    local output=$1
    local expected=$2

    if [[ $output != *"$expected"* ]]; then
        echo "Expected output to contain: $expected" >&2
        exit 1
    fi
}

assert_not_contains() {
    local output=$1
    local unexpected=$2

    if [[ $output == *"$unexpected"* ]]; then
        echo "Expected output not to contain: $unexpected" >&2
        exit 1
    fi
}

assert_line_matches() {
    local output=$1
    local pattern=$2

    if ! grep -Eq -- "$pattern" <<<"$output"; then
        echo "Expected an output line to match: $pattern" >&2
        exit 1
    fi
}

assert_occurrences() {
    local output=$1
    local expected=$2
    local text=$3
    local actual

    actual=$(grep -Foc -- "$text" <<<"$output")
    if [[ $actual -ne $expected ]]; then
        echo "Expected $expected occurrence(s) of '$text', got $actual" >&2
        exit 1
    fi
}

test_default_hides_exact_bar_titles() {
    local output
    output=$(run_cli)

    assert_contains "$output" "Working Tab"
    assert_occurrences "$output" 1 "Working Tab"
    assert_contains "$output" "debug status-bar issue"
    assert_not_contains "$output" "terminal_101"
    assert_not_contains "$output" "terminal_102"
}

test_show_bars_restores_bar_panes_in_all_mode() {
    local output
    output=$(run_cli --all --show-bars)

    assert_contains "$output" "terminal_101"
    assert_contains "$output" "terminal_102"
    assert_contains "$output" "Bars Only Tab"
    assert_contains "$output" "terminal_201"
    assert_contains "$output" "terminal_202"
    assert_not_contains "$output" "No panes after filtering."
}

test_floating_column_shows_three_states() {
    local output
    output=$(run_cli)

    assert_line_matches "$output" '^│ PANE_ID +│ FLOATING │ TITLE'
    assert_line_matches "$output" '^│ terminal_10 +│ no +│ editor'
    assert_line_matches "$output" '^│ terminal_11 +│ yes +│ debug status-bar issue'
    assert_line_matches "$output" '^│ terminal_12 +│ - +│ legacy pane'
}

test_all_mode_keeps_tabs_with_empty_state_rows() {
    local output
    output=$(run_cli --all)

    assert_contains "$output" "Bars Only Tab"
    assert_contains "$output" "Empty Tab"
    assert_occurrences "$output" 1 \
        "No panes after filtering. Use --show-bars to include bar panes."
    assert_occurrences "$output" 1 "No panes."
    assert_line_matches "$output" '^│ No panes after filtering\. Use --show-bars to include bar panes\. +│$'
    assert_line_matches "$output" '^│ No panes\. +│$'
}

test_current_mode_shows_filtered_empty_state() {
    local output
    output=$(run_cli_for_pane 201)

    assert_contains "$output" "Bars Only Tab"
    assert_contains "$output" \
        "No panes after filtering. Use --show-bars to include bar panes."
    assert_not_contains "$output" "Working Tab"
    assert_not_contains "$output" "Empty Tab"
}

test_default_hides_exact_bar_titles
echo "PASS: default hides exact bar titles"
test_show_bars_restores_bar_panes_in_all_mode
echo "PASS: --show-bars restores bar panes in --all mode"
test_floating_column_shows_three_states
echo "PASS: FLOATING column shows yes, no, and unknown"
test_all_mode_keeps_tabs_with_empty_state_rows
echo "PASS: --all keeps tabs with empty-state rows"
test_current_mode_shows_filtered_empty_state
echo "PASS: current mode shows a filtered empty-state row"
