#!/usr/bin/env bash
set -eo pipefail

# Script to retrieve pstore logs from a crashed kernel via S-Boot upload mode.
# Until support for entering upload mode on panic is patched into mainline,
# you'll have to do it yourself by entering upload mode manually after a panic.

SCRIPT_PATH=$(dirname $(realpath -s $0))
# Adjust to fit memory range of your pstore
$SCRIPT_PATH/../sboot_dump/samupload.py range 0x51000000 0x51100000
echo "Moving dump to pstore.bin..."
mv range.bin pstore.bin
