# Scenario helpers for the internal passthrough network load balancer fixture.

function scenario::validate_outputs -a tf_output_file
  set -gx BACKEND_MIG_NAME (jq -r '.backend_mig_name.value' "$tf_output_file")
  set -gx FORWARDING_RULE_NAME (jq -r '.forwarding_rule_name.value' "$tf_output_file")
  set -gx FORWARDING_RULE_IP (jq -r '.forwarding_rule_ip.value' "$tf_output_file")
  set -gx ZONE_OUTPUT (jq -r '.zone.value' "$tf_output_file")
  set -gx CLIENT_INSTANCE_NAME (jq -r '.client_instance_name.value' "$tf_output_file")

  for output_name in BACKEND_MIG_NAME FORWARDING_RULE_NAME FORWARDING_RULE_IP ZONE_OUTPUT CLIENT_INSTANCE_NAME
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
  set -l max_attempts 30
  set -l wait_between_attempts 10

  common::log "Waiting for internal passthrough load balancer at $lb_ip to be ready..."

  # Internal LB can only be accessed from within the VPC, so we test from the client VM
  for attempt in (seq 1 $max_attempts)
    set -l result (gcloud compute ssh "$CLIENT_INSTANCE_NAME" \
      --zone "$ZONE_OUTPUT" \
      --command "curl -s --connect-timeout 5 --max-time 10 'http://$lb_ip/' -o /dev/null && echo OK" 2>/dev/null)

    if test "$result" = "OK"
      common::log "Internal passthrough load balancer is ready and responding to requests"
      return 0
    end

    if test $attempt -eq $max_attempts
      printf 'Internal passthrough load balancer not responding after %s attempts\n' "$max_attempts" >&2
      return 1
    end

    if test (math "$attempt % 3") -eq 0
      common::log "Still waiting for internal passthrough load balancer... (attempt $attempt/$max_attempts)"
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

  common::log "Generating traffic through the internal passthrough network load balancer from the client VM..."
  set -l lb_ip "$FORWARDING_RULE_IP"
  set -l attempts 15

  # Internal LB can only be accessed from within the VPC, so we run traffic from the client VM
  for i in (seq 1 $attempts)
    common::trace_command gcloud compute ssh \"$CLIENT_INSTANCE_NAME\" \
      --zone \"$ZONE_OUTPUT\" \
      --command \"curl -D - -o /dev/null --connect-timeout 5 http://$lb_ip/?curl=$i\"
    common::trace_command gcloud compute ssh \"$CLIENT_INSTANCE_NAME\" \
      --zone \"$ZONE_OUTPUT\" \
      --command \"nc -vz $lb_ip 80\"
  end
end

function scenario::print_next_steps
  printf '\nNext steps:\n'
  printf '  - Allow several minutes for internal passthrough load balancer logs to ingest.\n'
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

  if test -z "$forwarding_rule_name" -o "$forwarding_rule_name" = "null"
    printf 'Missing Terraform output: forwarding_rule_name\n' >&2
    return 1
  end

  scenario::__ensure_time_defaults

  if not set -q OUTPUT_DIR
    set -gx OUTPUT_DIR ./nlb-passthrough-internal-fixtures-out
  end
  mkdir -p "$OUTPUT_DIR"

  set -l agg_output "$OUTPUT_DIR/nlb_passthrough_internal_logs.jsonl"
  # Filter by resource type and forwarding rule name for internal passthrough NLB
  set -l resource_filter "resource.type=\"l4_ps_rule\""
  set -l rule_filter "resource.labels.forwarding_rule_name=\"$forwarding_rule_name\""

  common::log "Exporting internal passthrough load balancer logs for forwarding rule $forwarding_rule_name"
  common::log "Writing results to $agg_output"

  common::trace_command "gcloud logging read \"$rule_filter AND timestamp >= \\\"$START_TIME\\\" AND timestamp <= \\\"$END_TIME\\\"\" \
    --format=json \
    --project \"$PROJECT_ID\" \
    --limit=\"$MAX_RESULTS\" >\"$agg_output\""

  set -l gcloudStatus $status
  if test $gcloudStatus -ne 0
    common::log "Error exporting logs: $gcloudStatus"
    return 1
  end

  set -l log_count (jq '. | length' "$agg_output" 2>/dev/null)
  if test -z "$log_count"
    set log_count 0
  end

  common::log "Results written to $agg_output"
  common::log "Exported $log_count log entries"
end

