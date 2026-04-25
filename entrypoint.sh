#!/usr/bin/env bash
set -euo pipefail

mkdir -p /home/pi /workspace

exec "$@"
