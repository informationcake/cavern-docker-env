#!/bin/sh
# A corrected wait-for-it.sh script

set -e

HOST=$(echo "$1" | cut -d: -f1)
PORT=$(echo "$1" | cut -d: -f2)
shift
CMD="$@"

# Wait for the service to be available by checking the host and port
until nc -z "$HOST" "$PORT"; do
  >&2 echo "Service at $HOST:$PORT is unavailable - sleeping"
  sleep 1
done

>&2 echo "Service is up - executing command"
exec $CMD
