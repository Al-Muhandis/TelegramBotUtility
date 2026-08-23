#!/usr/bin/env bash
################################################################################

set -xeuo pipefail

sudo bash -c '
    apt-get update
    apt-get install -y lazarus
' >/dev/null

declare -rx INSTANTFPCOPTIONS='-Fu/usr/lib/lazarus/*/components/lazutils'

instantfpc '.github/workflows/make.pas' build