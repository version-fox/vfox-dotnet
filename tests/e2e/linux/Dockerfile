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

# The Ubuntu E2E target: a clean machine with the native libraries a .NET
# SDK needs, a pinned vfox and a pinned mise. No SDK here on purpose: dotnet
# may only come from what vfox installs. The Go test drives every phase
# through exec calls.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

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
    && rm --recursive --force /tmp/vfox-extract /tmp/vfox.tar.gz \
    && vfox --version

# mise decodes a JSON null differently from vfox, and issue #17 only shows up
# there, so the listing is checked through mise as well.
ARG MISE_VERSION=2026.10.21
ARG MISE_SHA256=f56cc56b462eaae60aa7a33dffd24f641847b52e098b69e4a5064c4b8bbe03cb
RUN curl --fail --silent --show-error --location --output /tmp/mise.tar.gz \
        "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-x64.tar.gz" \
    && echo "${MISE_SHA256}  /tmp/mise.tar.gz" | sha256sum --check \
    && mkdir /tmp/mise-extract \
    && tar --extract --gzip --file /tmp/mise.tar.gz --directory /tmp/mise-extract --strip-components=2 \
        "mise/bin/mise" \
    && install --mode=0755 /tmp/mise-extract/mise /usr/local/bin/mise \
    && rm --recursive --force /tmp/mise-extract /tmp/mise.tar.gz \
    && mise --version

COPY metadata.lua /e2e/metadata.lua
COPY hooks /e2e/hooks
COPY lib /e2e/lib

WORKDIR /e2e
CMD ["sleep", "infinity"]
