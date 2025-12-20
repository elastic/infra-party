# GCP Setup

This document covers the prerequisites and configuration for running GCP-based scenarios (VPC Flow Logs, Network Load Balancer).

## Prerequisites

- **Terraform v1.5+**
- **Google provider v5.0+** (downloaded automatically by Terraform)
- **Fish shell v3.6+** (helper scripts are written in fish; bash/zsh are not supported)
- **jq** (for JSON processing)
- **curl** and **netcat** (used to generate NLB traffic from your workstation)
- **Go 1.21+** (only required for the VPC flow scenario traffic runner)

## GCP Authentication

Make sure you are logged into gcloud in **two** different ways:

```bash
# Interactive login for gcloud CLI
gcloud auth login

# Application default credentials for Terraform
gcloud auth application-default login
```

## Configuration

### Environment File

Copy the example environment file and adjust the values:

```bash
cp config.env.example config.env
$EDITOR config.env
```

Required variables:
- `PROJECT_ID`: Your GCP project ID
- `REGION`: GCP region (e.g., `us-central1`)
- `ZONE`: GCP zone (e.g., `us-central1-a`)
- `SCENARIO`: Set to `vpc-flow` or `nlb` (helper scripts override this)

### Environment Variables

These can be set when running `export` commands:

| Variable | Default | Description |
|----------|---------|-------------|
| `START_TIME` | now - 20m | UTC timestamp (`YYYY-MM-DDTHH:MM:SSZ`) for log window start |
| `END_TIME` | now | UTC timestamp for log window end |
| `MAX_RESULTS` | 2000 | Max log entries returned by `gcloud logging read` |
| `OUTPUT_DIR` | `./vpc-fixtures-out` or `./nlb-fixtures-out` | Directory for exported logs |
| `RESOURCE_PREFIX` | `gcp-fixture` | Prefix for Terraform resource names |

### Destroy Options

- `--dry-run` (default): Runs `terraform plan -destroy` without destroying
- `--dry-run=false`: Actually destroys resources

## Cost Warning

> **Warning:** Running GCP scenarios provisions billable Google Cloud resources.
> Proxy Network Load Balancers incur hourly forwarding rule and proxy-only subnet
> costs even when idle. Destroy the scenario as soon as you finish exporting logs.

## Troubleshooting

### No logs exported yet

Flow logs take about 10 minutes to appear; proxy NLB connection logs typically take 2–5 minutes. Re-run export or adjust `START_TIME`/`END_TIME`.

### Load balancer not responding

Backends might still be initializing. `run.fish` already waits for readiness, but you can confirm status via:

```bash
gcloud compute instance-groups managed list-instances
```

### Destroy fails with `resourceInUseByAnotherResource`

Forwarding rules may still reference the proxy-only subnet. Wait a minute and re-run:

```bash
./run.fish destroy --scenario=<name> --dry-run=false
```

### Costs creeping up

Proxy load balancers incur per-hour forwarding rule and proxy-only subnet charges. Always destroy the scenario after exporting the data you need.

