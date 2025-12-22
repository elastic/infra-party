# Kubernetes init-container log repro (local otelcol-contrib)

This scenario reproduces [issue #42810](https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/42810): `k8s_observer` does not surface init container names, so `receiver_creator` rules that rely on `container_name` cannot match init containers.

## Prereqs
- A Kubernetes cluster (minikube or kind)
- `kubectl` configured for that cluster
- A local `otelcol-contrib` binary (release or dev build)

## Deploy the workload

```fish
# Initial deploy
./k8s/init-container-logs/deploy-workload.fish

# Restart pods to re-run init containers (useful for testing within TTL window)
./k8s/init-container-logs/deploy-workload.fish --restart
```

Or manually:
```bash
kubectl apply -k k8s/init-container-logs/
kubectl get pods -n infra-party-k8s-init-logs
```

This deploys:
- Namespace `infra-party-k8s-init-logs`
- Deployment `loggen` with:
  - Init containers: `init-seed`, `init-migrate`
  - Main container: `app`
  - Sidecar: `sidecar`
- Pod annotation `logs.opentelemetry.io/include-containers: "init-seed,app,sidecar"`

## Run the collector

```fish
./k8s/init-container-logs/run-collector.fish

# Or specify a dev build
./k8s/init-container-logs/run-collector.fish /path/to/otelcol-contrib
```

Or manually:
```bash
otelcol-contrib --config k8s/init-container-logs/collector/otelcol-local.yaml
```

## What to look for

The `run-collector.fish` script filters the collector output and shows which containers are discovered.

### Before the fix (buggy behavior)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  k8s_observer init-container repro (issue #42810)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Expected containers in annotation: init-seed, app, sidecar

  BEFORE fix: only 'app', 'sidecar' discovered
  AFTER fix:  all four containers discovered

  Config enables: observe_pending_pods + observe_init_containers

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Running collector... (Ctrl+C to stop)

═══════════════════════════════════════════════════════════════════════════
  Collector ready. Waiting for endpoint discovery...
═══════════════════════════════════════════════════════════════════════════

═══ LOGGEN POD CONTAINERS DISCOVERED ═══
  ✓ app
  ✓ sidecar
  ✗ init-seed (NOT FOUND - this is the bug!)
  ✗ init-migrate (NOT FOUND - this is the bug!)
```

### After the fix (expected behavior)

```
═══ LOGGEN POD CONTAINERS DISCOVERED ═══
  ✓ app
  ✓ sidecar
  ✓ init-seed
  ✓ init-migrate
```

All four containers should be discovered when `observe_pending_pods` and `observe_init_containers` are enabled.

## How it works

The collector config uses:
- `k8s_observer` to watch pods
- `receiver_creator` with a rule that matches pods by annotation
- A `nop` receiver template (does nothing, but its creation is logged)

The key insight: we don't need to read actual logs to prove the bug. We just need to observe whether `receiver_creator` creates receivers for init containers.

## Config for the fix

The fix adds new options to `k8s_observer`:

```yaml
extensions:
  k8s_observer:
    observe_pending_pods: true      # Required: observe pods in Pending phase
    observe_init_containers: true   # Required: emit init container endpoints
    # init_container_terminated_ttl: 15m  # Optional: how long terminated init containers remain observable
```

Both `observe_pending_pods` and `observe_init_containers` must be enabled to observe init containers.

## Forcing init containers to rerun

```fish
./k8s/init-container-logs/deploy-workload.fish --restart
```

This restarts the deployment, causing init containers to run again. Useful for testing within the `init_container_terminated_ttl` window (default 15 minutes).

## Cleanup

```bash
kubectl delete -k k8s/init-container-logs/
```
