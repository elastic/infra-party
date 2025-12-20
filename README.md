# Infra Party

Infra Party provides infrastructure scenarios for generating and collecting observability data. Use it to test log pipelines, validate collector configurations, or generate realistic fixture data.

## Scenarios

| Scenario | Platform | Description | Docs |
|----------|----------|-------------|------|
| **VPC Flow Logs** | GCP | Generates internal VM traffic and exports subnet flow logs | [README](lib/scenarios/vpc-flow/README.md) |
| **Network Load Balancer** | GCP | Provisions a TCP proxy NLB and exports connection logs | [README](lib/scenarios/nlb/README.md) |
| **k8s Init Container Logs** | Kubernetes | Reproduces k8s_observer init-container gap (issue #42810) | [README](k8s/init-container-logs/README.md) |

## Quick Start

### GCP Scenarios

See [GCP Setup](docs/gcp-setup.md) for prerequisites and authentication.

```bash
# Configure your project
cp config.env.example config.env
$EDITOR config.env

# Run a scenario
./run.fish generate --scenario=vpc-flow
./run.fish export --scenario=vpc-flow
./run.fish destroy --scenario=vpc-flow --dry-run=false
```

### Kubernetes Scenarios

```bash
# Deploy workload
./k8s/init-container-logs/deploy-workload.fish

# Run local collector
./k8s/init-container-logs/run-collector.fish
```

## Repository Structure

```
infra-party/
├── docs/                    # Setup guides
├── k8s/                     # Kubernetes scenarios (kubectl-only)
│   └── init-container-logs/ # k8s_observer init-container repro
├── lib/
│   ├── common.fish          # Shared helper functions
│   └── scenarios/           # Scenario implementations
├── terraform/
│   └── modules/             # Terraform modules for GCP scenarios
└── run.fish                 # Main entry point for GCP scenarios
```

## Adding New Scenarios

> Note: Usage of an LLM is highly recommended for this repo.

### GCP Scenarios (Terraform-based)

1. Create a Terraform module under `terraform/modules/<scenario-name>/`
2. Update `terraform/main.tf`, `variables.tf`, and `outputs.tf`
3. Add a `lib/scenarios/<scenario-name>.fish` helper implementing:
   - `scenario::validate_outputs`
   - `scenario::run_traffic`
   - `scenario::export_logs`
   - `scenario::print_next_steps`
4. Add a README at `lib/scenarios/<scenario-name>/README.md`

### Kubernetes Scenarios (kubectl-only)

1. Create a directory under `k8s/<scenario-name>/`
2. Add Kustomize manifests and helper scripts
3. Add a self-contained README
