#!/usr/bin/env bash
set -eo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: $0 stacktrace-or-oops.txt"
  exit 1
fi

# Add toolchain to PATH
export PATH="$PATH:$(pwd)/../toolchain-mainline/bin"
OBJDUMP=arm-none-eabi-objdump

# Decode oops
"$(pwd)/linux-mainline/scripts/decode_stacktrace.sh" "$(pwd)/linux-mainline/vmlinux" "$(pwd)/linux-mainline" "$(pwd)" < "$1"
