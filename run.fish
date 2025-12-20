#!/usr/bin/env fish
# Unified entrypoint for generating and destroying fixture infrastructure.

function usage
  printf 'Usage: run.fish <generate|destroy|export> [options]\n'
  printf '\nOptions:\n'
  printf '  --scenario=<name>        Scenario to operate on (required).\n'
  printf '  --dry-run=true|false     Destroy only: plan destroy instead of apply (default true).\n'
  printf '  --help                   Show this help message.\n\n'
end

set -l script_path (status --current-filename)
set -l script_dir (realpath (dirname $script_path))
set -l terraform_dir "$script_dir/terraform"

argparse --name fixtures --min-args=1 'h/help' 's/scenario=' 'dry-run=' -- $argv
or exit 1

if set -q _flag_help
  usage
  exit 0
end

set -l command $argv[1]
set -l args $argv[2..-1]

switch $command
  case 'generate' 'destroy' 'export'
  case '*'
    printf 'Unknown command: %s\n' "$command" >&2
    usage
    exit 1
end

if test (count $args) -gt 0
  printf 'Unexpected positional arguments: %s\n' (string join ' ' $args) >&2
  usage
  exit 1
end

set -l dry_run true
if set -q _flag_dry_run
  if test "$command" != 'destroy'
    printf '--dry-run is only valid for the destroy command.\n' >&2
    exit 1
  end
  set -l dry_run_value (string lower $_flag_dry_run[-1])
  switch $dry_run_value
    case 'true' 'false'
      set dry_run $dry_run_value
    case '*'
      printf 'Invalid value for --dry-run. Use true or false.\n' >&2
      exit 1
  end
end

if set -q _flag_scenario
  set -gx SCENARIO $_flag_scenario[-1]
else if set -q _flag_s
  set -gx SCENARIO $_flag_s[-1]
end

if not set -q SCENARIO
  printf 'SCENARIO is required. Provide --scenario=<name> or set the SCENARIO env var.\n' >&2
  exit 1
end

if not set -q RESOURCE_PREFIX
  set -gx RESOURCE_PREFIX gcp-fixture
end

set -l env_file
if set -q ENV_FILE
  set env_file $ENV_FILE
else
  set env_file "$script_dir/config.env"
end

source "$script_dir/lib/common.fish"
if test -f "$env_file"
  common::load_env_file "$env_file"
end

common::require_env_vars PROJECT_ID REGION ZONE; or exit 1
common::require_commands gcloud jq terraform; or exit 1

common::ensure_gcloud_authenticated; or exit 1
common::export_terraform_env; or exit 1

common::terraform_init "$terraform_dir" >/dev/null; or exit 1

set -l scenario_file
if test "$command" = 'generate' -o "$command" = 'export'
  set scenario_file "$script_dir/lib/scenarios/$SCENARIO.fish"
  if not test -f "$scenario_file"
    printf 'Unknown scenario: %s\n' "$SCENARIO" >&2
    exit 1
  end
  source "$scenario_file"
end

switch $command
  case 'generate'
    common::terraform_apply "$terraform_dir"; or exit 1

    common::log "Collecting Terraform outputs..."
    set -l tf_output_file (mktemp)
    common::terraform_output_json "$terraform_dir" >"$tf_output_file"
    or begin
      rm -f "$tf_output_file"
      exit 1
    end

    scenario::validate_outputs "$tf_output_file"; or begin
      rm -f "$tf_output_file"
      exit 1
    end

    if functions -q scenario::deploy_artifacts
      scenario::deploy_artifacts "$script_dir"; or begin
        rm -f "$tf_output_file"
        exit 1
      end
    end
    rm -f "$tf_output_file"

    scenario::run_traffic "$script_dir"; or begin
      printf 'Traffic generation failed.\n' >&2
      exit 1
    end
    scenario::print_next_steps
  case 'export'
    common::log "Collecting Terraform outputs..."
    set -l tf_output_file (mktemp)
    common::terraform_output_json "$terraform_dir" >"$tf_output_file"
    or begin
      rm -f "$tf_output_file"
      exit 1
    end

    scenario::export_logs "$tf_output_file"; or begin
      rm -f "$tf_output_file"
      exit 1
    end
    rm -f "$tf_output_file"
  case 'destroy'
    common::log "Terraform destroy running with dry-run=$dry_run (scenario=$SCENARIO)"
    if test "$dry_run" = 'true'
      common::terraform_plan_destroy "$terraform_dir"
    else
      # Note the scenario is passed implicitly as a global environment variable.
      common::terraform_destroy "$terraform_dir"
    end
    common::log "Terraform destroy complete."
end
