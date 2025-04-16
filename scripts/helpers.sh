#!/usr/bin/env bash

check_workspace() {
echo "Checking for valid workspace type..."
workspace=${WORKSPACE_TYPE}
found=false
VALID_WORKSPACES=(
	personal
	work
)
for item in "${VALID_WORKSPACES[@]}"; do
  if [[ "$item" == "$workspace" ]]; then
    found=true
    break
  fi
done

if [ ! -z "$workspace" ]; then
  echo "Workspace is valid. Current value is $workspace."
  return 0
else
  echo "Workspace is not set. Please select workspace type."
  return 1
fi
}

check_workspace_and_exit() {
  valid_workspace=check_workspace
  if ! $valid_workspace; then
    echo "Invalid workspace type. Exiting. Please run make set-workspace to continue."
    exit 1
  fi
}
