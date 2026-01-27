#!/usr/bin/env fish
# Automated test for receiver_creator endpoint-change behavior.
# Deploys workload, runs collector, triggers label changes, verifies expected events.
#
# Usage:
#   ./test.fish
#   ./test.fish --collector-bin /path/to/otelcol-contrib

set -l script_dir (dirname (status -f))
set -l config_path "$script_dir/collector/otelcol-local.yaml"
set -l namespace infra-party-endpoint-change

# Parse arguments
set -l collector_bin otelcol-contrib
for i in (seq (count $argv))
    switch $argv[$i]
        case --collector-bin
            set collector_bin $argv[(math $i + 1)]
    end
end

# Test state
set -l log_file (mktemp)
set -l collector_pid ""
set -l passed 0
set -l failed 0
set -l test_results

# Cleanup function
function cleanup
    set -l pid $argv[1]
    set -l ns $argv[2]
    set -l log $argv[3]
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Cleanup"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Stop collector
    if test -n "$pid"
        kill $pid 2>/dev/null
        echo "Stopped collector (pid $pid)"
    end
    
    # Delete workload
    kubectl delete -k (dirname (status -f)) --ignore-not-found=true 2>/dev/null
    echo "Deleted workload"
    
    # Keep temp file for debugging (don't remove)
    if test -f "$log"
        echo "Log file preserved at: $log"
    end
end

# Check function - verifies a pattern exists in log
function check_log
    set -l description $argv[1]
    set -l pattern $argv[2]
    set -l log $argv[3]
    
    if grep -q "$pattern" "$log" 2>/dev/null
        set_color green
        echo "  ✓ PASS: $description"
        set_color normal
        return 0
    else
        set_color red
        echo "  ✗ FAIL: $description"
        set_color normal
        return 1
    end
end

# Check function - verifies NO lifecycle events occurred after a marker line
function check_no_lifecycle_after
    set -l description $argv[1]
    set -l log $argv[2]
    set -l marker_line $argv[3]
    
    # Count lifecycle events after marker line (use wc -l for reliable counting)
    set -l events_after (tail -n +$marker_line "$log" 2>/dev/null | grep -E "starting receiver|restarting receiver|removing receiver|starting new receiver" | wc -l | tr -d ' ')
    
    if test "$events_after" -eq 0
        set_color green
        echo "  ✓ PASS: $description"
        set_color normal
        return 0
    else
        set_color red
        echo "  ✗ FAIL: $description (found $events_after unexpected events)"
        set_color normal
        return 1
    end
end

# Header
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  receiver_creator endpoint-change automated test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Collector: $collector_bin"
echo "  Log file:  $log_file"
echo ""

# Step 1: Full reset - delete namespace and redeploy
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Step 1: Reset environment (delete namespace, redeploy)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Kill any existing collector processes to avoid port conflicts
pkill -9 -f otelcontribcol 2>/dev/null
echo "  Killed any existing collector processes"

# Delete namespace if it exists (this ensures clean state)
kubectl delete ns $namespace --ignore-not-found=true --wait=true 2>/dev/null
echo "  Deleted namespace (if existed)"

# Deploy fresh
if not kubectl apply -k "$script_dir"
    set_color red
    echo "Failed to deploy workload"
    set_color normal
    exit 1
end
echo "  Workload deployed"
if not kubectl wait --for=condition=Ready pod -l app=loggen -n $namespace --timeout=60s
    set_color red
    echo "Pods did not become ready"
    set_color normal
    cleanup "" $namespace $log_file
    exit 1
end
echo "  Workload deployed and ready"

# Step 2: Start collector in background
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Step 2: Start collector"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
$collector_bin --config "$config_path" > "$log_file" 2>&1 &
set collector_pid $last_pid
echo "  Collector started (pid $collector_pid)"

# Give collector a moment to start (or fail)
sleep 2

# Check if collector is still running
if not kill -0 $collector_pid 2>/dev/null
    set_color red
    echo "  Collector failed to start! Log output:"
    set_color normal
    cat "$log_file"
    cleanup "" $namespace $log_file
    exit 1
end
echo "  Collector running"

# Step 3: Wait for initial discovery
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Step 3: Wait for endpoint discovery (15s)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sleep 15
echo "  Discovery period complete"

# Step 4: Verify initial receivers started
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Step 4: Verify initial receivers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if check_log "nop/always started" "starting receiver.*nop/always" "$log_file"
    set passed (math $passed + 1)
else
    set failed (math $failed + 1)
end

if check_log "nop/frontend started" "starting receiver.*nop/frontend" "$log_file"
    set passed (math $passed + 1)
else
    set failed (math $failed + 1)
end

# Step 5: Change irrelevant label (should NOT trigger any lifecycle events)
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Step 5: Change irrelevant label (expect NO restart/remove/start)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# Record current log line count as marker
set -l marker_line (wc -l < "$log_file" | tr -d ' ')
set marker_line (math $marker_line + 1)

kubectl label pod -n $namespace -l app=loggen environment=test --overwrite >/dev/null 2>&1
echo "  Added environment=test label, waiting 8s for detection..."
sleep 8

if check_no_lifecycle_after "no lifecycle events for irrelevant label change" "$log_file" "$marker_line"
    set passed (math $passed + 1)
else
    set failed (math $failed + 1)
    # Debug: show what events occurred
    echo "  Debug: Events after marker line $marker_line:"
    tail -n +$marker_line "$log_file" 2>/dev/null | grep -E "starting receiver|restarting receiver|removing receiver|starting new receiver|keeping receiver|config unchanged" | head -10
end

# Step 6: Change tier=premium
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Step 6: Change tier=premium (expect remove frontend, start premium)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl label pod -n $namespace -l app=loggen tier=premium --overwrite >/dev/null 2>&1
echo "  Labels changed, waiting 8s for detection..."
sleep 8

if check_log "nop/frontend removed" "removing receiver.*nop/frontend" "$log_file"
    set passed (math $passed + 1)
else
    set failed (math $failed + 1)
end

if check_log "nop/premium started (new match)" "starting new receiver.*nop/premium" "$log_file"
    set passed (math $passed + 1)
else
    set failed (math $failed + 1)
end

# Step 7: Change version=v2
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Step 7: Change version=v2 (expect restart nop/always)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl label pod -n $namespace -l app=loggen version=v2 --overwrite >/dev/null 2>&1
echo "  Labels changed, waiting 8s for detection..."
sleep 8

if check_log "nop/always restarted" "restarting receiver.*nop/always" "$log_file"
    set passed (math $passed + 1)
else
    set failed (math $failed + 1)
end

# Stop collector
kill $collector_pid 2>/dev/null

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
set_color green
echo "  Passed: $passed"
set_color normal
if test $failed -gt 0
    set_color red
end
echo "  Failed: $failed"
set_color normal
echo ""

# Show relevant log excerpts if any failures
if test $failed -gt 0
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Relevant log lines:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    grep -E "starting receiver|restarting receiver|removing receiver|starting new receiver" "$log_file" 2>/dev/null | head -20
    echo ""
    echo "  Full log: $log_file"
    echo ""
end

# Cleanup
cleanup "" $namespace ""

# Exit with appropriate code
if test $failed -gt 0
    exit 1
else
    set_color green
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ALL TESTS PASSED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    set_color normal
    exit 0
end
