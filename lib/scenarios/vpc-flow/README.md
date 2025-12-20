# VPC Flow Logs Scenario

Generates internal VM traffic on Google Cloud Platform and exports subnet flow logs.

## Prerequisites

See [GCP Setup](../../../docs/gcp-setup.md) for prerequisites and authentication.

## Quick Start

```bash
# Generate infrastructure and traffic
./run.fish generate --scenario=vpc-flow

# Wait ~10 minutes for flow logs to aggregate

# Export logs
./run.fish export --scenario=vpc-flow
```

Results are written to `./vpc-fixtures-out/vpc_logs.jsonl`.

## Destroy

```bash
./run.fish destroy --scenario=vpc-flow --dry-run=false
```

## How It Works

1. **Generate**: Terraform creates the VPC, subnet, firewall rules, and a Managed Instance Group with 2 VMs
2. **Traffic**: A Go helper connects to MIG instances over SSH to create east-west traffic between VMs, plus calls to Google Cloud APIs
3. **Ingestion Delay**: VPC flow logs use 5-minute aggregation windows; expect ~10 minutes before logs appear
4. **Export**: Queries Cloud Logging for `resource.type="gce_subnetwork"` and writes JSONL

## Infrastructure Details

| Component | Description |
|-----------|-------------|
| **VPC Network** | Custom mode network with a single subnet (`10.10.0.0/20`) |
| **VPC Flow Logs** | Enabled with 5-minute aggregation and full metadata sampling |
| **Firewall Rules** | Internal traffic (all protocols within subnet), SSH access (from anywhere) |
| **Managed Instance Group** | Regional MIG with 2 Debian 12 instances |
| **Traffic Generation** | Automated intra-VPC traffic plus calls to Google Cloud APIs |

## Log Output Format

- **Resource type**: `resource.type="gce_subnetwork"`
- **Schema**: VPC Flow Logs schema (5-minute aggregation)

Key fields in `jsonPayload`:
- `reporter`: Which VM reported the flow
- `connection`: Source/destination IPs, ports, protocol
- `src` / `dest`: Compute metadata (instance ID, tags, subnet)
- `bytes_sent` / `packets_sent`: Traffic volume

Example query to verify logs in Cloud Console:

```
resource.type="gce_subnetwork"
logName="projects/YOUR_PROJECT/logs/compute.googleapis.com%2Fvpc_flows"
```

