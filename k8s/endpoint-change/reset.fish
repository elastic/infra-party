#!/usr/bin/env fish
# Fully reset the endpoint-change test environment.
# Deletes the namespace and redeploys fresh.

set -l namespace infra-party-endpoint-change
set -l script_dir (dirname (status -f))

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Resetting endpoint-change test environment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "Deleting namespace $namespace..."
kubectl delete ns $namespace 2>/dev/null
or echo "(namespace didn't exist)"

echo ""
echo "Redeploying workload..."
$script_dir/deploy-workload.fish
