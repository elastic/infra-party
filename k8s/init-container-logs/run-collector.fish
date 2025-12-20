#!/usr/bin/env fish
# Run a local otelcol-contrib binary to observe k8s_observer + receiver_creator behavior.
# Usage: ./run-collector.fish [path-to-otelcol-contrib]
#
# If no path is given, assumes `otelcol-contrib` is on PATH.

set -l script_dir (dirname (status -f))
set -l config_path "$script_dir/collector/otelcol-local.yaml"

# Collector binary (default: otelcol-contrib on PATH)
set -l collector_bin $argv[1]
if test -z "$collector_bin"
    set collector_bin otelcol-contrib
end

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  k8s_observer init-container repro (issue #42810)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Expected containers in annotation: init-seed, app, sidecar"
echo ""
echo "  BEFORE fix: only 'app', 'sidecar' discovered"
echo "  AFTER fix:  all four containers discovered"
echo ""
echo "  Config enables: observe_pending_pods + observe_init_containers"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Running collector... (Ctrl+C to stop)"
echo ""

# Run collector and filter output
$collector_bin --config "$config_path" 2>&1 | while read -l line
    # Extract container endpoints from k8s_observer discovery
    if string match -q '*added endpoints*' -- $line
        # Check if this mentions our namespace
        if string match -q '*infra-party-k8s-init-logs*' -- $line
            echo ""
            set_color cyan
            echo "═══ LOGGEN POD CONTAINERS DISCOVERED ═══"
            set_color normal
            
            # Look for each container we expect
            for container in app sidecar init-seed init-migrate
                if string match -q "*/$container\"*" -- $line
                    set_color green
                    echo "  ✓ $container"
                    set_color normal
                else
                    set_color red
                    echo "  ✗ $container (NOT FOUND - this is the bug!)"
                    set_color normal
                end
            end
            echo ""
        end
        
    # Show receiver creation/start events  
    else if string match -q '*Starting receiver*' -- $line
        # Only show if it's for our containers
        if string match -q '*loggen*' -- $line; or string match -q '*infra-party*' -- $line
            set_color green
            echo "✓ RECEIVER STARTED for loggen pod"
            set_color normal
        end
        
    # Show errors (but not SSH LogLevel=ERROR noise)
    else if string match -q '*error*' -- $line; and not string match -q '*LogLevel=ERROR*' -- $line
        if not string match -q '*context canceled*' -- $line
            set_color red
            echo "✗ "(string sub -l 100 -- $line)
            set_color normal
        end
        
    # Show ready message
    else if string match -q '*Everything is ready*' -- $line
        set_color green
        echo ""
        echo "═══════════════════════════════════════════════════════════════════════════"
        echo "  Collector ready. Waiting for endpoint discovery..."
        echo "  (Endpoints appear ~1 second after startup)"
        echo "═══════════════════════════════════════════════════════════════════════════"
        echo ""
        set_color normal
    end
end
