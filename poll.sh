#!/bin/sh
# Usage: poll.sh <networkmanager-connection> <ssh-host>
# Prints key=value lines for Model.parse. Read-only on both machines.

if [ "$(nmcli -t -g GENERAL.STATE connection show "$1" 2>/dev/null)" != activated ]; then
  echo tunnel=down
  exit 0
fi
echo tunnel=up

# Only runs while the tunnel is up, so nothing goes over the public internet.
# BatchMode: never stop to ask for a password.
timeout 30 ssh -o BatchMode=yes -o ConnectTimeout=8 -- "$2" sh -s \
  < "$(dirname "$0")/remote.sh" 2>/dev/null || echo ssh=fail
