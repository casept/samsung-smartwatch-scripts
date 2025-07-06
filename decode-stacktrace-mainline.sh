#!/usr/bin/env bash
set -eo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: $0 stacktrace-or-oops.txt"
  exit 1
fi

OBJDUMP=arm-none-eabi-objdump

# Decode oops
"$(pwd)/linux-samsung-smartwatch/scripts/decode_stacktrace.sh" "$(pwd)/linux-samsung-smartwatch/vmlinux" "$(pwd)/linux-samsung-smartwatch" "$(pwd)" < "$1"
