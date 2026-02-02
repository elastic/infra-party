#!/usr/bin/env fish
# Change labels on the loggen pod to trigger receiver_creator OnChange behavior.
# Usage:
#   ./change-labels.fish tier=premium
#   ./change-labels.fish version=v2
#   ./change-labels.fish --reset

set -l namespace infra-party-endpoint-change

if test "$argv[1]" = "--reset"
    echo "Resetting pod to original state (rollout restart)..."
    kubectl rollout restart deployment/loggen -n $namespace
    kubectl rollout status deployment/loggen -n $namespace --timeout=60s
    echo ""
    echo "Pod recreated with original labels from deployment spec."
    echo ""
    echo "For a full reset (delete namespace + redeploy), use: ./reset.fish"
    exit 0
end

if test (count $argv) -lt 1
    echo "Usage:"
    echo "  ./change-labels.fish tier=premium"
    echo "  ./change-labels.fish version=v2"
    echo "  ./change-labels.fish --reset"
    exit 1
end

echo "Updating labels: $argv"
kubectl label pod -n $namespace -l app=loggen $argv --overwrite

echo ""
echo "Current labels:"
kubectl get pod -n $namespace -l app=loggen -o jsonpath='{range .items[*]}{.metadata.name}{"\\n"}  app={.metadata.labels.app}{"\\n"}  tier={.metadata.labels.tier}{"\\n"}  version={.metadata.labels.version}{"\\n"}{end}'
