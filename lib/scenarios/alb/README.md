# Application Load Balancer Logs Scenario

Provisions either a global or regional external Application Load Balancer (HTTP/HTTPS) on Google Cloud Platform, generates traffic through the load balancer, and exports request logs with optional TLS metadata.

## Prerequisites

See [GCP Setup](../../../docs/gcp-setup.md) for prerequisites and authentication.

## Quick Start

```bash
# Generate infrastructure and traffic
./run.fish generate --scenario=alb

# Wait a few minutes for load balancer logs to aggregate

# Export logs
./run.fish export --scenario=alb
```

Results are written to `./alb-fixtures-out/alb_logs.jsonl`.

## Destroy

```bash
./run.fish destroy --scenario=alb --dry-run=false
```

## Configuration Options

### Load Balancer Scope

Set `LOAD_BALANCER_SCOPE` in `config.env`:

- **`regional`** (default): Regional external Application Load Balancer with Standard network tier
- **`global`**: Global external Application Load Balancer with Premium network tier

### TLS

By default, TLS is enabled with self-signed certificates. Traffic is generated over HTTPS and logs include TLS protocol and cipher information.

## How It Works

1. **Generate**: Terraform creates the VPC, backend MIG running nginx, health checks, and the ALB (global or regional based on config)
2. **Traffic**: The script waits for backend instances and load balancer readiness, then generates HTTP/HTTPS traffic from the local machine using curl
3. **Ingestion Delay**: ALB logs typically take 2–5 minutes to appear
4. **Export**: Queries Cloud Logging for the appropriate resource type and writes JSONL

## Infrastructure Details

| Component | Description |
|-----------|-------------|
| **VPC Network** | Custom mode network with subnet (`10.20.0.0/20`) |
| **Backend MIG** | Zonal managed instance group (2 Debian 12 VMs) running nginx |
| **Health Checks** | HTTP health check on port 80 with firewall rules for Google LB ranges |
| **Client VM** | Dedicated client instance for traffic generation |
| **Proxy-only Subnet** | Regional-only subnet (`10.20.16.0/24`) with `REGIONAL_MANAGED_PROXY` purpose (regional ALB only) |
| **TLS Configuration** | Self-signed certificates generated via Terraform's TLS provider |
| **Target Proxy** | HTTP or HTTPS proxy that routes to the backend service |
| **Load Balancer** | External managed Application Load Balancer (EXTERNAL_MANAGED) with 100% logging |

### Global vs Regional

| Aspect | Global | Regional |
|--------|--------|----------|
| Resources | `google_compute_*` | `google_compute_region_*` |
| Network Tier | Premium | Standard |
| IP Address | Global anycast | Regional |
| Provisioning Time | 10-15 minutes | Faster |

## Log Output Format

**Resource type**:
- Global: `resource.type="http_load_balancer"`
- Regional: `resource.type="http_external_regional_lb_rule"`

**Key labels**:
- `project_id`, `url_map_name`, `backend_service_name`
- `matched_url_path_rule`, `target_proxy_name`, `forwarding_rule_name`
- `region` (regional only)

**Key fields**:
- `httpRequest`: method, URL, status, response size, user agent, latency
- `jsonPayload.tls.protocol`: TLS protocol version (e.g., "TLS 1.3")
- `jsonPayload.tls.cipher`: Cipher suite used for the connection

Example query to verify logs in Cloud Console:

```
resource.type="http_load_balancer"
resource.labels.url_map_name="YOUR_URL_MAP"
```

