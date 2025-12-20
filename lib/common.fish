#!/usr/bin/env fish
# Shared helpers for fixture automation scripts.

function common::log
  printf '==> %s\n' (string join ' ' $argv) >&2
end

function common::load_env_file -a env_file
  if test -f "$env_file"
    common::log "Loading environment from $env_file"
    source "$env_file"
  end
end

function common::require_env_vars
  set -l missing
  for var_name in $argv
    if not set -q $var_name
      set missing $missing $var_name
      continue
    end
    eval test -n \"\$$var_name\"
    or set missing $missing $var_name
  end

  if test (count $missing) -gt 0
    printf 'Missing required environment variables: %s\n' (string join ', ' $missing) >&2
    return 1
  end
end

function common::require_commands
  set -l missing
  for cmd in $argv
    if not type -q $cmd
      set missing $missing $cmd
    end
  end

  if test (count $missing) -gt 0
    printf 'Missing required command-line tools: %s\n' (string join ', ' $missing) >&2
    return 1
  end
end

function common::ensure_gcloud_authenticated
  if not gcloud auth list --format='value(account)' | grep -q "@"
    printf 'No active gcloud account. Run `gcloud auth login` first.\n' >&2
    return 1
  end
end

function common::export_terraform_env
  common::require_env_vars PROJECT_ID REGION ZONE RESOURCE_PREFIX SCENARIO; or return 1

  set -gx TF_VAR_project_id $PROJECT_ID
  set -gx TF_VAR_region $REGION
  set -gx TF_VAR_zone $ZONE
  set -gx TF_VAR_resource_prefix $RESOURCE_PREFIX
  set -gx TF_VAR_scenario $SCENARIO
  
  # Optional: set load balancer scope for alb scenario
  if set -q LOAD_BALANCER_SCOPE
    set -gx TF_VAR_load_balancer_scope $LOAD_BALANCER_SCOPE
  end
end

function common::__terraform_exec -a dir subcommand
  set -l args $argv[3..-1]
  terraform -chdir="$dir" $subcommand $args
end

function common::terraform_init -a dir
  set -l args $argv[2..-1]
  common::log "Initializing Terraform in $dir"
  common::__terraform_exec $dir "init" -upgrade $args
end

function common::terraform_apply -a dir
  set -l args $argv[2..-1]
  common::log "Applying Terraform configuration in $dir"
  common::__terraform_exec $dir "apply" $args
end

function common::terraform_destroy -a dir
  set -l args $argv[2..-1]
  common::log "Destroying Terraform configuration in $dir"
  common::__terraform_exec $dir "destroy" $args
end

function common::terraform_plan_destroy -a dir
  set -l args $argv[2..-1]
  common::log "Planning Terraform destroy in $dir"
  common::__terraform_exec $dir "plan" -destroy $args
end

function common::terraform_output_json -a dir
  set -l args $argv[2..-1]
  terraform -chdir="$dir" output -json $args
end

function common::trace_command
  set -l orig_fish_trace $fish_trace
  set fish_trace 1
  eval $argv
  set -l cmd_status $status
  set fish_trace $orig_fish_trace
  return $cmd_status
  echo "\n"
end

