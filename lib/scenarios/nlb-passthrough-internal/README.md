# Internal Passthrough Network Load Balancer Logs Scenario

Provisions a regional internal passthrough Network Load Balancer on Google Cloud Platform, drives client traffic from within the VPC, and exports connection logs.

## Prerequisites

See [GCP Setup](../../../docs/gcp-setup.md) for prerequisites and authentication.

## Quick Start

```bash
# Generate infrastructure and traffic
./run.fish generate --scenario=nlb-passthrough-internal

# Wait a few minutes for load balancer logs to aggregate

# Export logs
./run.fish export --scenario=nlb-passthrough-internal
```

Results are written to `./nlb-passthrough-internal-fixtures-out/nlb_passthrough_internal_logs.jsonl`.

## Destroy

```bash
./run.fish destroy --scenario=nlb-passthrough-internal --dry-run=false
```

## How It Works

1. **Generate**: Terraform creates the VPC, backend MIG running nginx, health checks, and the internal passthrough NLB
2. **Traffic**: The script waits for backend readiness, then fires curl/netcat traffic from the client VM via SSH (internal LBs are only accessible within the VPC)
3. **Ingestion Delay**: Connection logs typically take 2–5 minutes to appear
4. **Export**: Queries Cloud Logging for `resource.type="loadbalancing.googleapis.com/InternalNetworkLoadBalancerRule"` and writes JSONL

> **Note:** The internal load balancer can only be accessed from within the VPC network. Traffic is generated automatically from the client VM via SSH.

## Infrastructure Details

| Component | Description |
|-----------|-------------|
| **VPC Network** | Custom mode network with subnet (`10.40.0.0/20`) |
| **Backend MIG** | Zonal managed instance group (2 Debian 12 VMs) running NGINX |
| **Health Checks** | Regional TCP health check on port 80 with Google health check probe ranges |
| **Client VM** | Dedicated client instance within the VPC that generates traffic via SSH |
| **Load Balancer** | Regional internal passthrough NLB (`INTERNAL` scheme) with 100% connection logging |
| **Internal IP** | Load balancer uses an internal IP from the subnet, accessible only within the VPC |

## Log Output Format

- **Resource type**: `resource.type="loadbalancing.googleapis.com/InternalNetworkLoadBalancerRule"`

**Key labels**:
- `project_id`, `region`
- `forwarding_rule_name`, `backend_service_name`
- `backend_group_name`, `backend_group_type`, `backend_group_scope`
- `backend_network_name`, `backend_subnetwork_name`

**Key fields in `jsonPayload`**:
- `@type`: `"type.googleapis.com/google.cloud.loadbalancing.type.InternalNetworkLoadBalancerLogEntry"`
- `connection`: `clientIp`, `clientPort`, `serverIp`, `serverPort`, `protocol`
- `startTime`, `endTime`: Connection timestamps
- `packetsReceived`, `packetsSent`: Packet counts
- `rtt`: Round-trip time (optional, e.g., `"0.000702357s"`)

Example query to verify logs in Cloud Console:

```
resource.type="loadbalancing.googleapis.com/InternalNetworkLoadBalancerRule"
resource.labels.forwarding_rule_name="YOUR_FORWARDING_RULE"
```

