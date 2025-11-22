#!/bin/bash

commit=true
origin=$(git remote get-url origin)
if [[ $origin == *statsig-io/statuspage* ]]
then
  commit=false
fi

declare -a KEYSARRAY
declare -a URLSARRAY

urlsConfig="public/urls.cfg"
echo "Reading $urlsConfig"
while IFS='=' read -r key url
do
  echo "  $key=$url"
  KEYSARRAY+=("$key")
  URLSARRAY+=("$url")
done < "$urlsConfig"

echo "***********************"
echo "Starting health checks with ${#KEYSARRAY[@]} configs:"

mkdir -p logs
mkdir -p public/status

# Initialize service states file
STATES_FILE="public/status/.service_states.json"
if [ ! -f "$STATES_FILE" ]; then
    echo "{}" > "$STATES_FILE"
fi

# Check if jq is available, if not use a simple workaround
if ! command -v jq &> /dev/null; then
    echo "Warning: jq not found. Installing jq..."
    sudo apt-get update && sudo apt-get install -y jq || {
        echo "Error: jq is required but could not be installed"
        exit 1
    }
fi

for (( index=0; index < ${#KEYSARRAY[@]}; index++ ))
do
  key="${KEYSARRAY[index]}"
  url="${URLSARRAY[index]}"
  echo "  $key=$url"

  # Get current state from states file
  current_state=$(jq -r ".[\"$key\"] // null" "$STATES_FILE")
  consecutive_failures=0
  issue_number=""
  
  if [ "$current_state" != "null" ] && [ -n "$current_state" ]; then
    consecutive_failures=$(echo "$current_state" | jq -r '.consecutive_failures // 0')
    issue_number=$(echo "$current_state" | jq -r '.issue_number // ""')
  fi

  # Check service status
  for i in {1..3}
  do
    response=$(curl -o /dev/null -s -w '%{http_code} %{time_total}' --silent --output /dev/null "$url")
    http_code=$(echo "$response" | cut -d ' ' -f 1)
    time_total=$(echo "$response" | cut -d ' ' -f 2)
    echo "    $http_code $time_total"
    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 202 ] || [ "$http_code" -eq 301 ] || [ "$http_code" -eq 302 ] || [ "$http_code" -eq 307 ]; then
      result="success"
    else
      result="failed"
    fi
    if [ "$result" = "success" ]; then
      break
    fi
    sleep 5
  done
  
  dateTime=$(date +'%Y-%m-%d %H:%M')
  
  # Update consecutive failures counter
  if [ "$result" = "failed" ]; then
    consecutive_failures=$((consecutive_failures + 1))
    # Record first failure time if this is the first failure
    if [ "$consecutive_failures" -eq 1 ]; then
      first_failure_time=$(date '+%Y-%m-%d %H:%M:%S')
    else
      first_failure_time=$(echo "$current_state" | jq -r '.first_failure_time // ""')
    fi
  else
    # Reset counter on success
    consecutive_failures=0
    first_failure_time=""
  fi
  
  # Update states file
  if [ "$result" = "failed" ]; then
    temp_file=$(mktemp)
    jq ".[\"$key\"] = {
      \"consecutive_failures\": $consecutive_failures,
      \"last_status\": \"$result\",
      \"first_failure_time\": \"$first_failure_time\",
      \"issue_number\": ${issue_number:-null}
    }" "$STATES_FILE" > "$temp_file"
    mv "$temp_file" "$STATES_FILE"
  else
    # On success, keep issue_number but reset failures
    temp_file=$(mktemp)
    jq ".[\"$key\"] = {
      \"consecutive_failures\": 0,
      \"last_status\": \"$result\",
      \"first_failure_time\": \"\",
      \"issue_number\": ${issue_number:-null}
    }" "$STATES_FILE" > "$temp_file"
    mv "$temp_file" "$STATES_FILE"
  fi
  
  if [[ $commit == true ]]
  then
    echo "$dateTime, $result, $time_total" >> "public/status/${key}_report.log"
    tail -8640 "public/status/${key}_report.log" > "public/status/${key}_report.log.tmp"
    mv "public/status/${key}_report.log.tmp" "public/status/${key}_report.log"
    
    # Send notification
    if [ -f "scripts/send-notification.sh" ]; then
      notification_output=$(bash scripts/send-notification.sh "$key" "$url" "$result" "$consecutive_failures" "$issue_number" 2>&1)
      echo "$notification_output"
      
      # Extract issue number if it was just created
      new_issue_number=$(echo "$notification_output" | grep "ISSUE_NUMBER=" | cut -d '=' -f 2)
      if [ -n "$new_issue_number" ] && [ -z "$issue_number" ]; then
        issue_number="$new_issue_number"
        # Update states file with the new issue number
        temp_file=$(mktemp)
        jq ".[\"$key\"].issue_number = $issue_number" "$STATES_FILE" > "$temp_file"
        mv "$temp_file" "$STATES_FILE"
      fi
    fi
  else
    echo "    $dateTime, $result, $time_total"
  fi
done

if [[ $commit == true ]]
then
  echo "committing logs"
  git config --global user.name 'github-actions[bot]'
  git config --global user.email 'github-actions[bot]@users.noreply.github.com'
  git add -A --force public/status/
  # Include the states file in the commit
  git add -f "$STATES_FILE" 2>/dev/null || true
  git commit -am '[Automated] Update Health Check Logs' || echo "No changes to commit"
  git push || echo "Push failed or no changes"
fi
