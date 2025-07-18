#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

ACTION=$1 # Expects 'start' or 'stop'

if [ -z "$ACTION" ]; then
  echo "Usage: $0 [start|stop]"
  exit 1
fi

# Define service directories (relative to this script's location)
SERVICE_DIRS=(
  "infra/haproxy"
  "infra/reg"
  "platform/src-posix-mapper"
  "platform/src-cavern"
)

start_services() {
  echo "--- Starting Patrick's Containers ---"
  for dir in "${SERVICE_DIRS[@]}"; do
    echo "Starting service in $dir..."
    (cd "$dir" && ./doit) # Execute doit script in its directory
    sleep 5 # Increased sleep to give containers more time to start/register
    echo "Done."
  done
  echo "All services started. Check logs for details."
}

stop_services() {
  echo "--- Stopping Patrick's Containers ---"
  # Stop in reverse order for dependencies
  for (( i=${#SERVICE_DIRS[@]}-1; i>=0; i-- )); do
    dir="${SERVICE_DIRS[$i]}"
    echo "Stopping service in $dir..."
    (cd "$dir" && ./killit) # Execute killit script in its directory
    sleep 2 # Give some time for container to stop
    echo "Done."
  done
  echo "All services stopped."
}

case "$ACTION" in
  start)
    start_services
    ;;
  stop)
    stop_services
    ;;
  *)
    echo "Invalid action: $ACTION"
    echo "Usage: $0 [start|stop]"
    exit 1
    ;;
esac

