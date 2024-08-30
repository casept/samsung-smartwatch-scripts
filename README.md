# samsung-smartwatch-scripts

My private scripts to aid Samsung smartwatch mainlining / AsteroidOS porting.

Works on my machine.

## Directory structure

This repo expects to be cloned next to my fork of the downstream vendor kernel and mainline Linux.

## Usage

The main entrypoint is the `Justfile`. Install `just`, then run it to get information about available tasks.

Some tasks also require `zellij`, `docker` / `podman` or `heimdall` (Grimler's fork, binary named `heimdall-grimler` on PATH)
to be installed.

AsteroidOS-related tasks assume you're building it on a remote server. Add this server to your SSH config, then set
the `BUILDSERVER` env var to it's name in the config.
