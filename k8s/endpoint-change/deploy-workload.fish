#!/usr/bin/env fish
# Deploy or redeploy the endpoint-change workload.
# Usage: ./deploy-workload.fish [--restart]

set -l script_dir (dirname (status -f))

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  receiver_creator endpoint-change workload"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if test "$argv[1]" = "--restart"; or test "$argv[1]" = "-r"
    echo "Restarting deployment to re-run pods..."
    echo ""
    kubectl rollout restart deploy/loggen -n infra-party-endpoint-change
    echo ""
    echo "Waiting for rollout to complete..."
    kubectl rollout status deploy/loggen -n infra-party-endpoint-change --timeout=60s
else
    echo "Applying workload manifests..."
    echo ""
    kubectl apply -k "$script_dir"
    echo ""
    echo "Waiting for pods to be ready..."
    kubectl wait --for=condition=Ready pod -l app=loggen -n infra-party-endpoint-change --timeout=60s
end

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Current pods:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get pods -n infra-party-endpoint-change -o wide
echo ""
echo "Current labels:"
kubectl get pod -n infra-party-endpoint-change -l app=loggen -o jsonpath='{range .items[*]}{.metadata.name}{"\\n"}  app={.metadata.labels.app}{"\\n"}  tier={.metadata.labels.tier}{"\\n"}  version={.metadata.labels.version}{"\\n"}{end}'
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  • Run collector:  ./k8s/endpoint-change/run-collector.fish"
echo "  • Change labels:  ./k8s/endpoint-change/change-labels.fish tier=premium"
echo "  • Reset labels:   ./k8s/endpoint-change/change-labels.fish --reset"
echo "  • Cleanup:        kubectl delete -k $script_dir"
echo ""
