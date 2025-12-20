# External Passthrough Network Load Balancer Logs Scenario

Provisions a regional external passthrough Network Load Balancer on Google Cloud Platform, drives client traffic through the forwarding rule, and exports connection logs.

## Prerequisites

See [GCP Setup](../../../docs/gcp-setup.md) for prerequisites and authentication.

## Quick Start

```bash
# Generate infrastructure and traffic
./run.fish generate --scenario=nlb-passthrough

# Wait a few minutes for load balancer logs to aggregate

# Export logs
./run.fish export --scenario=nlb-passthrough
```

Results are written to `./nlb-passthrough-fixtures-out/nlb_passthrough_logs.jsonl`.

## Destroy

```bash
./run.fish destroy --scenario=nlb-passthrough --dry-run=false
```

## How It Works

1. **Generate**: Terraform creates the VPC, backend MIG running nginx, health checks, and the external passthrough NLB
2. **Traffic**: The script waits for backend readiness and for the load balancer to respond, then fires curl/netcat traffic from the local machine
3. **Ingestion Delay**: Connection logs typically take 2–5 minutes to appear
4. **Export**: Queries Cloud Logging for `resource.type="loadbalancing.googleapis.com/ExternalNetworkLoadBalancerRule"` and writes JSONL

## Infrastructure Details

| Component | Description |
|-----------|-------------|
| **VPC Network** | Custom mode network with subnet (`10.30.0.0/20`) |
| **Backend MIG** | Zonal managed instance group (2 Debian 12 VMs) running NGINX |
| **Health Checks** | Regional TCP health check on port 80 |
| **Client VM** | Dedicated client instance that generates HTTP and raw TCP traffic (iperf3, curl, netcat) |
| **Load Balancer** | Regional external passthrough NLB (`EXTERNAL` scheme) with 100% connection logging |
| **Network Tier** | STANDARD tier addresses to minimize cost during testing |

## Log Output Format

- **Resource type**: `resource.type="loadbalancing.googleapis.com/ExternalNetworkLoadBalancerRule"`

**Key labels**:
- `project_id`, `network_name`, `region`, `load_balancing_scheme`, `protocol`
- `forwarding_rule_name`, `target_proxy_name`
- `backend_target_name`, `backend_target_type`
- `backend_name`, `backend_type`, `backend_scope`, `backend_scope_type`

**Key fields in `jsonPayload.connection`**:
- Client/server IPs and ports
- Protocol numbers
- Byte counts
- Start/end timestamps
- Latency

Example query to verify logs in Cloud Console:

```
resource.type="loadbalancing.googleapis.com/ExternalNetworkLoadBalancerRule"
resource.labels.forwarding_rule_name="YOUR_FORWARDING_RULE"
```

