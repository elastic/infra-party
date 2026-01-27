#!/usr/bin/env fish
# Run a local otelcol-contrib binary to observe receiver_creator endpoint change behavior.
# Usage: ./run-collector.fish [path-to-otelcol-contrib]

set -l script_dir (dirname (status -f))
set -l config_path "$script_dir/collector/otelcol-local.yaml"

# Collector binary (default: otelcol-contrib on PATH)
set -l collector_bin $argv[1]
if test -z "$collector_bin"
    set collector_bin otelcol-contrib
end

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  receiver_creator endpoint-change scenario"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Expected lifecycle events:"
echo "  - Start: nop/always + nop/frontend"
echo "  - Change tier=frontend -> tier=premium: remove nop/frontend, start nop/premium"
echo "  - Change version=v1 -> v2: restart nop/always (resource attr change)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Running collector... (Ctrl+C to stop)"
echo ""

$collector_bin --config "$config_path" 2>&1 | while read -l line
    if string match -qi '*starting receiver*' -- $line
        if string match -qi '*endpoint-change*' -- $line; or string match -qi '*infra-party-endpoint-change*' -- $line; or string match -qi '*nop/*' -- $line
            set_color green
            echo "✓ START "(string sub -l 120 -- $line)
            set_color normal
        end
    else if string match -qi '*restarting receiver*' -- $line
        set_color yellow
        echo "↺ RESTART "(string sub -l 120 -- $line)
        set_color normal
    else if string match -qi '*removing receiver*' -- $line
        set_color red
        echo "✗ REMOVE "(string sub -l 120 -- $line)
        set_color normal
    else if string match -qi '*starting new receiver (template now matches)*' -- $line
        set_color green
        echo "✓ NEW MATCH "(string sub -l 120 -- $line)
        set_color normal
    else if string match -qi '*Everything is ready*' -- $line
        set_color green
        echo ""
        echo "═══════════════════════════════════════════════════════════════════════════"
        echo "  Collector ready. Waiting for endpoint discovery..."
        echo "═══════════════════════════════════════════════════════════════════════════"
        echo ""
        set_color normal
    end
end
