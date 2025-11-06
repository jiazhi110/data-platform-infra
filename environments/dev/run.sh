#!/bin/bash
# This script provides a safe wrapper around Terraform commands to ensure
# that only the application-level modules are affected, protecting the
# core networking infrastructure.

set -e

# The specific module to target.
TARGET_MODULE="module.ingestion"

# Get the command from the first argument.
COMMAND=$1

# --- Helper Functions ---
function show_usage() {
  echo "Usage: ./run.sh [plan|apply|destroy]"
  echo "  plan    - Runs 'terraform plan' targeting only the application module."
  echo "  apply   - Runs 'terraform apply' targeting only the application module."
  echo "  destroy - Runs 'terraform destroy' targeting only the application module."
}

# --- Main Logic ---
case "$COMMAND" in
  plan)
    echo "==> Running 'terraform plan' for ${TARGET_MODULE}..."
    terraform plan -target=${TARGET_MODULE}
    ;;

  apply)
    echo "==> Running 'terraform apply' for ${TARGET_MODULE}..."
    terraform apply -auto-approve -target=${TARGET_MODULE}
    ;;

  destroy)
    echo "==> Running 'terraform destroy' for ${TARGET_MODULE}..."
    terraform destroy -auto-approve -target=${TARGET_MODULE}
    ;;

  *)
    echo "Error: Invalid command '$COMMAND'"
    echo ""
    show_usage
    exit 1
    ;;
esac


echo ""
echo "Operation successful for ${TARGET_MODULE}."
