#!/bin/sh
# Full verification flow for the CDC primitive library.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sh "$HERE/run_lint.sh"
sh "$HERE/run_formal.sh"
sh "$HERE/run_sim.sh"
sh "$HERE/run_synth.sh"
echo '=== CDC primitives: complete verification flow passed (lint + formal + sim + synth) ==='
