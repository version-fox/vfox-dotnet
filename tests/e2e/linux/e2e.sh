#!/usr/bin/env bash
# Copyright 2026 Han Li and contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Ubuntu E2E: register the local plugin, install a .NET SDK through vfox,
# select it and run the real dotnet binary. Run inside the image built from
# tests/e2e/linux/Dockerfile (see docs/e2e.md).
set -eo pipefail

version="${DOTNET_VERSION:-8.0}"

echo "== vfox $(vfox --version)"

echo "== register the local dotnet plugin"
if ! vfox info dotnet >/dev/null 2>&1; then
    (cd /e2e && zip -q -r /tmp/dotnet-plugin.zip metadata.lua hooks lib)
    vfox add dotnet --source /tmp/dotnet-plugin.zip
fi

echo "== vfox search dotnet $version"
vfox search dotnet "$version" > /tmp/search.out
if [ ! -s /tmp/search.out ]; then
    echo "vfox search returned no versions" >&2
    exit 1
fi

echo "== vfox install dotnet@$version"
if ! vfox install "dotnet@$version" > /tmp/install.log 2>&1; then
    tail -40 /tmp/install.log >&2
    exit 1
fi
tail -3 /tmp/install.log

# vfox needs its shell hook for `use`; env -s applies the selection to this
# non-interactive shell (there is no PROMPT_COMMAND to do it for us).
eval "$(vfox activate bash)"
echo "== vfox use --global dotnet@$version"
vfox use --global "dotnet@$version"
eval "$(vfox env -s bash)"

echo "== verify the environment"
test -n "$DOTNET_ROOT"
test -d "$DOTNET_ROOT"
echo "DOTNET_ROOT=$DOTNET_ROOT"
echo "== vfox current dotnet"
vfox current dotnet

echo "== dotnet --version"
actual="$(dotnet --version)"
echo "dotnet --version = $actual"
major_minor="$(printf '%s' "$version" | cut -d. -f1,2)"
case "$actual" in
    "$major_minor".*) ;;
    *)
        echo "expected $major_minor.*, got $actual" >&2
        exit 1
        ;;
esac

echo "== dotnet --list-sdks"
dotnet --list-sdks | grep .

echo "PASS: dotnet installed and used through the vfox plugin on Ubuntu"
