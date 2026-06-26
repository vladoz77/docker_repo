#! /bin/bash
set -euo pipefail

GITLAB_URL="https://gitlab.devhomelab.site"
PAT_TOKEN="glpat-s2EVJY-cupw8VPjOFWZ3hm86MQp1OjMH.01.0w1oo84uf"
RUNNER_DESCRIPTION="$(hostname)-$(hostname -I | awk '{print $1}')"
RUNNER_TAGS="ubuntu"

# Check if run script as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Function to call GitLab API
gitlab_api() {
    local method=$1
    local endpoint_url=$2
    local data=('$@')
    shift 2

    local response http_code http_body
    response=$(curl -s -w "\n%{http_code}" \
      -X $method \
      --header "PRIVATE-TOKEN: ${PAT_TOKEN}" \
      --url "${GITLAB_URL}/${endpoint_url}" \
      "$@") || {
        echo "curl failed for ${method} ${endpoint_url}"
        return 1
      }


    http_code=$(echo "$response" | tail -n1)
    http_body=$(echo "$response" | sed '$d')

    if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
        echo "GitLab API error: HTTP $http_code" >&2
        return 1
    fi
    echo "$http_body"
}

create_runner_in_gitlab() {
  # Get list of runners from GitLab API with the specified description
  local runner_exists
  runner_exists=$(gitlab_api GET "/api/v4/runners/all" \
    | jq -r --arg name "$RUNNER_DESCRIPTION"  'any(.description == $name)' )

  # Check if runner already exists
  if [[ "$runner_exists" == true ]]; then
    echo "Runner ${RUNNER_DESCRIPTION} already exists"
    return 1
  fi

  # Create a new runner in GitLab
  local response 
  response=$(gitlab_api POST "/api/v4/user/runners" \
    --data "runner_type=instance_type" \
    --data "description=${RUNNER_DESCRIPTION}" \
    --data "tag_list=${RUNNER_TAGS}") 

  echo "Runner ${RUNNER_DESCRIPTION} success created"

  token=$(echo $response | jq -r '.token')

  if [[ -z "$token" ]]; then
    echo "Failed to retrieve runner token from GitLab API response"
    return 1
  fi

  echo "token = $token"
}

# Function to install gitlab-runner
install_runner() {
  # Check if runner already installed
  if command -v gitlab-runner >/dev/null 2>&1; then
    echo "Runner have already installed"
    return
  fi

  echo "Installing runner..."

  # Get os version
  source /etc/os-release

  # Install specific version
  case "$ID" in 
   
    ubuntu|debian)
      echo "installing debian version..."
      curl -fsSL https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | bash
      apt-get update
      apt-get install -y gitlab-runner 
      ;;
    
    rhel|centos|rocky|almalinux|fedora)
      echo "Installing RHEL version..."
      curl -fsSL https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh | bash
      dnf install -y gitlab-runner
      ;; 
    
    *)
      echo "Error OS version"
      return 1
      ;;
  esac

  echo "Runner installed successfully"
}

register_runner() {

  # Register the runner
  gitlab-runner register \
    --non-interactive \
    --url "${GITLAB_URL}" \
    --token "${token}" \
    --description "${RUNNER_DESCRIPTION}" \
    --tag-list "${RUNNER_TAGS}" \
    --executor "shell"

  echo "Runner ${RUNNER_DESCRIPTION} registered successfully"
}

# Create runner in GitLab
create_runner_in_gitlab || exit 1

# Install gitlab-runner
install_runner || exit 1

# Register gitlab runner
register_runner  || exit 1
