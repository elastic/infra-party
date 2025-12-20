# Network Load Balancer Logs Scenario

Provisions a regional external proxy TCP Network Load Balancer on Google Cloud Platform, drives client traffic through the forwarding rule, and exports connection logs.

## Prerequisites

See [GCP Setup](../../../docs/gcp-setup.md) for prerequisites and authentication.

## Quick Start

```bash
# Generate infrastructure and traffic
./run.fish generate --scenario=nlb

# Wait a few minutes for load balancer logs to aggregate

# Export logs
./run.fish export --scenario=nlb
```

Results are written to `./nlb-fixtures-out/nlb_logs.jsonl`.

## Destroy

```bash
./run.fish destroy --scenario=nlb --dry-run=false
```

## How It Works

1. **Generate**: Terraform creates the VPC, backend MIG, health checks, proxy-only subnet, and the TCP proxy load balancer
2. **Traffic**: The script waits for backend readiness and for the proxy to respond, then fires curl/netcat traffic from your local machine
3. **Ingestion Delay**: Proxy NLB connection logs typically take 2–5 minutes to appear
4. **Export**: Queries Cloud Logging for `resource.type="l4_proxy_rule"` and writes JSONL

## Infrastructure Details

| Component | Description |
|-----------|-------------|
| **VPC Network** | Custom mode network with subnet (`10.20.0.0/20`) |
| **Backend MIG** | Zonal managed instance group (2 Debian 12 VMs) running a simple HTTP server |
| **Health Checks** | TCP health check on port 80 with firewall rules for Google LB ranges |
| **Client VM** | Dedicated client instance that generates HTTP and raw TCP traffic |
| **Proxy-only Subnet** | Dedicated `/24` subnet (`10.20.16.0/24`) with `REGIONAL_MANAGED_PROXY` purpose |
| **Target Proxy** | Regional target TCP proxy resource that fronts the backend service |
| **Load Balancer** | Regional external proxy NLB (EXTERNAL_MANAGED) with 100% connection logging |
| **Network Tier** | STANDARD tier addresses to keep costs low during testing |

## Log Output Format

- **Resource type**: `resource.type="l4_proxy_rule"`

Key labels:
- `project_id`, `network_name`, `region`, `load_balancing_scheme`, `protocol`
- `forwarding_rule_name`, `target_proxy_name`
- `backend_target_name`, `backend_target_type`
- `backend_name`, `backend_type`, `backend_scope`, `backend_scope_type`

Key fields in `jsonPayload.connection`:
- Client/server IPs and ports
- Protocol numbers
- Byte counts
- Start/end timestamps
- Latency

Example query to verify logs in Cloud Console:

```
resource.type="l4_proxy_rule"
resource.labels.forwarding_rule_name="YOUR_FORWARDING_RULE"
```

