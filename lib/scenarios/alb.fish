# Scenario helpers for the regional application load balancer fixture.

function scenario::validate_outputs -a tf_output_file
  set -gx BACKEND_MIG_NAME (jq -r '.backend_mig_name.value' "$tf_output_file")
  set -gx FORWARDING_RULE_NAME (jq -r '.forwarding_rule_name.value' "$tf_output_file")
  set -gx FORWARDING_RULE_IP (jq -r '.forwarding_rule_ip.value' "$tf_output_file")
  set -gx ZONE_OUTPUT (jq -r '.zone.value' "$tf_output_file")
  set -gx ENABLE_TLS (jq -r '.enable_tls.value' "$tf_output_file")

  # Set protocol and curl options based on TLS setting
  if test "$ENABLE_TLS" = "true"
    set -gx PROTOCOL "https"
    set -gx CURL_OPTS "--insecure"
  else
    set -gx PROTOCOL "http"
    set -gx CURL_OPTS ""
  end

  for output_name in BACKEND_MIG_NAME FORWARDING_RULE_NAME FORWARDING_RULE_IP ZONE_OUTPUT
    set -l value (eval printf '%s' "\$$output_name")
    if test -z "$value" -o "$value" = "null"
      printf 'Missing Terraform output: %s\n' "$output_name" >&2
      return 1
    end
  end
end

function scenario::__wait_for_backends
  set -l max_attempts 18
  set -l wait_between_attempts 10
  set -l expected_size 2
  if set -q EXPECTED_BACKEND_MIN
    set expected_size $EXPECTED_BACKEND_MIN
  end

  for attempt in (seq 1 $max_attempts)
    set -l ready_count (gcloud compute instance-groups managed list-instances "$BACKEND_MIG_NAME" \
      --zone "$ZONE_OUTPUT" \
      --format=json | jq '[.[] | select(.instanceStatus == "RUNNING" and .currentAction == "NONE")] | length')

    if test $status -ne 0
      printf 'Failed to list instances for MIG %s\n' "$BACKEND_MIG_NAME" >&2
      return 1
    end

    if test "$ready_count" -ge "$expected_size"
      common::log "Backend instance group $BACKEND_MIG_NAME has $ready_count ready instances"
      return 0
    end

    if test $attempt -eq $max_attempts
      printf 'Backend instances not ready after %s attempts\n' "$max_attempts" >&2
      return 1
    end

    sleep $wait_between_attempts
  end
end

function scenario::__wait_for_load_balancer
  set -l lb_ip "$FORWARDING_RULE_IP"
  set -l max_attempts 50
  set -l wait_between_attempts 10

  common::log "Waiting for load balancer at $lb_ip to be ready..."

  for attempt in (seq 1 $max_attempts)
    if curl -s -f --connect-timeout 5 --max-time 10 $CURL_OPTS "$PROTOCOL://$lb_ip/" -o /dev/null
      common::log "Load balancer is ready and responding to requests"
      return 0
    end

    if test $attempt -eq $max_attempts
      printf 'Load balancer not responding after %s attempts\n' "$max_attempts" >&2
      return 1
    end

    if test (math "$attempt % 3") -eq 0
      common::log "Still waiting for load balancer... (attempt $attempt/$max_attempts)"
    end

    sleep $wait_between_attempts
  end
end

function scenario::run_traffic -a script_dir
  if not scenario::__wait_for_backends
    return 1
  end

  if not scenario::__wait_for_load_balancer
    return 1
  end

  if test "$ENABLE_TLS" = "true"
    common::log "Generating HTTPS traffic through the application load balancer from the local machine..."
  else
    common::log "Generating HTTP traffic through the application load balancer from the local machine..."
  end
  
  set -l lb_ip "$FORWARDING_RULE_IP"
  set -l attempts 15

  for i in (seq 1 $attempts)
    common::trace_command curl -D - -o /dev/null --connect-timeout 5 $CURL_OPTS \"$PROTOCOL://$lb_ip/?curl=\$i\"
  end
end

function scenario::print_next_steps
  printf '\nNext steps:\n'
  printf '  - Allow several minutes for load balancer logs to ingest.\n'
  printf '  - Run `./run.fish export --scenario=%s` to capture relevant entries.\n' "$SCENARIO"
  printf '  - Destroy the scenario with run.fish destroy --scenario=%s --dry-run=false when done.\n\n' "$SCENARIO"
end

function scenario::__ensure_time_defaults
  if not set -q START_TIME; or test -z "$START_TIME"
    if date -u -d '20 minutes ago' >/dev/null 2>&1
      set -gx START_TIME (date -u -d '20 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
    else
      set -gx START_TIME (TZ=UTC date -u -v -20M +%Y-%m-%dT%H:%M:%SZ)
    end
  end

  if not set -q END_TIME; or test -z "$END_TIME"
    if date -u >/dev/null 2>&1
      set -gx END_TIME (date -u +%Y-%m-%dT%H:%M:%SZ)
    else
      set -gx END_TIME (TZ=UTC date +%Y-%m-%dT%H:%M:%SZ)
    end
  end

  if not set -q MAX_RESULTS
    set -gx MAX_RESULTS 2000
  end
end

function scenario::export_logs -a tf_output_file
  set -l forwarding_rule_name (jq -r '.forwarding_rule_name.value' "$tf_output_file")
  set -l backend_service_name (jq -r '.backend_service_name.value' "$tf_output_file")
  set -l url_map_name (jq -r '.url_map_name.value' "$tf_output_file")
  set -l subnet_name (jq -r '.subnet_name.value' "$tf_output_file")
  set -l load_balancer_scope (jq -r '.load_balancer_scope.value' "$tf_output_file")

  if test -z "$forwarding_rule_name" -o "$forwarding_rule_name" = "null"
    printf 'Missing Terraform output: forwarding_rule_name\n' >&2
    return 1
  end

  scenario::__ensure_time_defaults

  if not set -q OUTPUT_DIR
    set -gx OUTPUT_DIR ./alb-fixtures-out
  end
  mkdir -p "$OUTPUT_DIR"

  set -l agg_output "$OUTPUT_DIR/alb_logs.jsonl"
  
  # Set resource type based on load balancer scope
  set -l resource_filter
  if test "$load_balancer_scope" = "global"
    set resource_filter "resource.type=\"http_load_balancer\""
    common::log "Exporting global application load balancer logs for URL map $url_map_name"
  else
    set resource_filter "resource.type=\"http_external_regional_lb_rule\""
    common::log "Exporting regional application load balancer logs for URL map $url_map_name"
  end
  
  set -l url_map_filter "resource.labels.url_map_name=\"$url_map_name\""

  common::log "Writing results to $agg_output"

  # Log the output of the GCloud command to the console.
  common::trace_command "gcloud logging read \"$resource_filter AND $url_map_filter AND timestamp >= \\\"$START_TIME\\\" AND timestamp <= \\\"$END_TIME\\\"\" \
    --format=json \
    --project \"$PROJECT_ID\" \
    --limit=\"$MAX_RESULTS\" >\"$agg_output\""

  set -l gcloudStatus $status
  if test $gcloudStatus -ne 0
    common::log "Error exporting logs: $gcloudStatus"
    return 1
  end

  # Count the number of log entries
  set -l log_count (jq '. | length' "$agg_output" 2>/dev/null)
  if test -z "$log_count"
    set log_count 0
  end

  common::log "Results written to $agg_output"
  common::log "Exported $log_count log entries"

  if test -n "$subnet_name"; and test "$subnet_name" != "null"
    printf '\nNote: The fixture subnet is %s. You can cross-reference VPC flow logs\n' "$subnet_name"
    printf 'to correlate backend activity with load balancer requests.\n\n'
  end

  if test -n "$backend_service_name"; and test "$backend_service_name" != "null"
    printf 'Backend service: %s\n' "$backend_service_name"
    printf 'You can also filter logs by backend_service_name if needed.\n\n'
  end
end
