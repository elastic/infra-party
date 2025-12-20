#!/usr/bin/env fish
# Deploy or redeploy the test workload with init containers.
# Usage: ./deploy-workload.fish [--restart]
#
# Without args: applies the kustomize manifests (creates if not exists)
# With --restart: restarts the deployment to re-run init containers

set -l script_dir (dirname (status -f))

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  k8s init-container test workload"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if test "$argv[1]" = "--restart"; or test "$argv[1]" = "-r"
    echo "Restarting deployment to re-run init containers..."
    echo ""
    kubectl rollout restart deploy/loggen -n infra-party-k8s-init-logs
    echo ""
    echo "Waiting for rollout to complete..."
    kubectl rollout status deploy/loggen -n infra-party-k8s-init-logs --timeout=60s
else
    echo "Applying workload manifests..."
    echo ""
    kubectl apply -k "$script_dir"
    echo ""
    echo "Waiting for pods to be ready..."
    kubectl wait --for=condition=Ready pod -l app=loggen -n infra-party-k8s-init-logs --timeout=60s
end

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Current pods:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get pods -n infra-party-k8s-init-logs -o wide
echo ""
echo "Containers in the loggen pod:"
kubectl get pod -n infra-party-k8s-init-logs -l app=loggen -o jsonpath='{range .items[*].status.containerStatuses[*]}  {.name}: {.state}{"\n"}{end}'
kubectl get pod -n infra-party-k8s-init-logs -l app=loggen -o jsonpath='{range .items[*].status.initContainerStatuses[*]}  {.name} (init): {.state}{"\n"}{end}'
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  • Run collector:  ./k8s/init-container-logs/run-collector.fish"
echo "  • Restart pods:   ./k8s/init-container-logs/deploy-workload.fish --restart"
echo "  • Cleanup:        kubectl delete -k $script_dir"
echo ""

