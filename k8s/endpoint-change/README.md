# receiver_creator endpoint-change scenario

This scenario validates the receiver_creator endpoint-change behavior added in the refactor:

- **Keep (no change)** when a label changes but doesn't affect any receiver's config or rule match.
- **Restart** when a receiver's effective config changes (resource attributes reference a label that changes).
- **Remove** when a template's rule no longer matches.
- **New match** when a template starts matching after a label change.

## Prereqs

- A Kubernetes cluster (minikube or kind)
- `kubectl` configured for that cluster
- A local `otelcol-contrib` binary (release or dev build)

## Building a custom collector

To test changes to `receiver_creator` or other components, build a custom collector from the `opentelemetry-collector-contrib` repo:

```bash
cd /path/to/opentelemetry-collector-contrib
cd cmd/otelcontribcol
make otelcontribcol
```

Then use the custom binary with any of the scripts:

```fish
# Automated test
./k8s/endpoint-change/test.fish --collector-bin /path/to/opentelemetry-collector-contrib/cmd/otelcontribcol/otelcol-contrib

# Manual run
./k8s/endpoint-change/run-collector.fish /path/to/opentelemetry-collector-contrib/cmd/otelcontribcol/otelcol-contrib
```

Tip: Add the binary to your PATH or create an alias for convenience:

```fish
set -gx PATH /path/to/opentelemetry-collector-contrib/cmd/otelcontribcol $PATH
```

## Automated test

Run the full test suite with a single command:

```fish
./k8s/endpoint-change/test.fish
# or specify a custom collector binary
./k8s/endpoint-change/test.fish --collector-bin /path/to/otelcol-contrib
```

This script:
1. Deploys the workload
2. Starts the collector
3. Verifies initial receivers start (`nop/always`, `nop/frontend`)
4. Changes `environment=test` (irrelevant label) and verifies **no** lifecycle events occur
5. Changes `tier=premium` and verifies `nop/frontend` removed, `nop/premium` started
6. Changes `version=v2` and verifies `nop/always` restarted
7. Reports pass/fail summary
8. Cleans up workload

Exit code is 0 if all tests pass, 1 otherwise.

## Manual testing

The sections below describe how to run the scenario manually for debugging.

## Deploy the workload

```fish
./k8s/endpoint-change/deploy-workload.fish
```

This deploys a `loggen` deployment with labels:

```
app=loggen
tier=frontend
version=v1
```

## Run the collector

```fish
./k8s/endpoint-change/run-collector.fish
# or specify a dev build
./k8s/endpoint-change/run-collector.fish /path/to/otelcol-contrib
```

## Trigger the four behaviors

1. **Keep (no change)** - change irrelevant label

```fish
./k8s/endpoint-change/change-labels.fish environment=test
```

Expected:
- No restart, no removal, no new receivers (the `environment` label is not referenced by any rule or resource attribute)

2. **New match + removal** (switch tier)

```fish
./k8s/endpoint-change/change-labels.fish tier=premium
```

Expected:
- `nop/frontend` removed
- `nop/premium` started (new match)

3. **Restart** (change resource attr label)

```fish
./k8s/endpoint-change/change-labels.fish version=v2
```

Expected:
- `nop/always` restarted (resource attribute `app.version` changes)

4. **Reset**

```fish
./k8s/endpoint-change/change-labels.fish --reset
```

## How it works

The collector config uses `k8s_observer` and `receiver_creator` with three templates
that match **pod container** endpoints:

- `nop/always` matches `app=loggen` and uses `app.version` from labels
- `nop/frontend` matches `tier=frontend`
- `nop/premium` matches `tier=premium`

**Initial state** (with labels `tier=frontend`, `version=v1`):
- `nop/always` starts (matches `app=loggen`)
- `nop/frontend` starts (matches `tier=frontend`)
- `nop/premium` does NOT start (no match for `tier=premium`)

Changing pod labels triggers `OnChange`:
- **keep** when the change doesn't affect config or rule match (no restart needed)
- **removal** when a rule no longer matches
- **new receiver** when a rule starts matching
- **restart** when computed resource attributes change

## Cleanup

```bash
kubectl delete -k k8s/endpoint-change/
```
