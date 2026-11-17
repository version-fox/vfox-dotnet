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

# The Ubuntu E2E target: a clean machine with the runtime libraries a .NET
# SDK needs and a pinned vfox. The plugin under test is copied in as source
# and the script packs and registers it, exactly as a user would.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# No SDK here on purpose: dotnet may only come from what vfox installs.
# libicu74 is the ICU runtime .NET needs for globalization on noble; the
# others are the transitive native dependencies of the SDK.
RUN apt-get update \
    && apt-get install --assume-yes --no-install-recommends \
        ca-certificates \
        curl \
        libicu74 \
        libssl3 \
        unzip \
        zip \
        zlib1g \
    && rm --recursive --force /var/lib/apt/lists/*

ARG VFOX_VERSION=1.1.0
ARG VFOX_SHA256=3b33c3c468b27bc17aecf0d6d3af24fe49fe204972984904a136a47b402a0ee4
RUN curl --fail --silent --show-error --location --output /tmp/vfox.tar.gz \
        "https://github.com/version-fox/vfox/releases/download/v${VFOX_VERSION}/vfox_${VFOX_VERSION}_linux_x86_64.tar.gz" \
    && echo "${VFOX_SHA256}  /tmp/vfox.tar.gz" | sha256sum --check \
    && mkdir /tmp/vfox-extract \
    && tar --extract --gzip --file /tmp/vfox.tar.gz --directory /tmp/vfox-extract --strip-components=1 \
        "vfox_${VFOX_VERSION}_linux_x86_64/vfox" \
    && install --mode=0755 /tmp/vfox-extract/vfox /usr/local/bin/vfox \
    && rm --recursive --force /tmp/vfox /tmp/vfox.tar.gz \
    && vfox --version

COPY metadata.lua /e2e/metadata.lua
COPY hooks /e2e/hooks
COPY lib /e2e/lib
COPY tests/e2e/linux/e2e.sh /e2e/e2e.sh

WORKDIR /e2e
