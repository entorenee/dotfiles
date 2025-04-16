#!/usr/bin/env bash
source ./scripts/helpers.sh

env_var="WORKSPACE_TYPE"

workspace=${WORKSPACE_TYPE}
valid_workspace=check_workspace

if $valid_workspace; then
    echo "Do you want to continue with this value?"
    select continue in yes no; do
      case $continue in
        yes)
          echo "No changes made."
          exit 0;;
        no)
          echo "Unsetting workspace value"
          workspace=""
          break;;
      esac
    done
fi

if [ -z "$workspace" ]; then
  echo "Please select workspace type"
  select new_workspace in "${VALID_WORKSPACES[@]}"; do
    case $new_workspace in
      personal|work)
        echo "Selected option $new_workspace"
        workspace=$new_workspace
        break;;
    esac
  done
fi

# Persist workspace to shell env
echo "Persisting workspace to the environment"
env_file=$HOME/.zshenv
existing_value=$(grep -E "^export $env_var=.+" $env_file) > /dev/null
if [ ! -z "$existing_value" ]; then
  value=${existing_value#*=}
  echo "Workspace type already set in $env_file. Overwriting value."
  sed -i -e "s|^export $env_var=.*|export $env_var=$workspace|" $env_file
else
cat >> $env_file << EOF
export $env_var=$workspace
EOF
fi
export $env_var=$workspace
echo "Environment persisted to $env_file. Open a new terminal for changes to take effect."
