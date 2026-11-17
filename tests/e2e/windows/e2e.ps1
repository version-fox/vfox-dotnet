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

# Windows E2E: register the local plugin, install a .NET SDK through vfox,
# select it and run the real dotnet binary. Runs natively on a GitHub-hosted
# Windows runner (see docs/e2e.md).
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$version = if ($env:DOTNET_VERSION) { $env:DOTNET_VERSION } else { '8.0' }
$vfoxVersion = '1.1.0'
$vfoxSha256 = '1bbec8fffddbb62de0d93030c3f6203c69680662bc65257ca4a5e611cb607d0a'

function Step([string]$message) { Write-Host "== $message" }
function Assert([bool]$condition, [string]$message) {
    if (-not $condition) { throw "ASSERT: $message" }
}

$repo = if ($env:GITHUB_WORKSPACE) { $env:GITHUB_WORKSPACE } else { (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path }
$work = Join-Path $PSScriptRoot '.work'
New-Item -ItemType Directory -Force -Path $work | Out-Null
$vfoxExe = Join-Path $work 'vfox.exe'

# Install a pinned vfox from its release archive; the checksum is the one of
# vfox_1.1.0_windows_x86_64.zip. Keep the two variables in step when upgrading.
if (-not (Test-Path $vfoxExe)) {
    $zip = Join-Path $work 'vfox.zip'
    $url = "https://github.com/version-fox/vfox/releases/download/v$vfoxVersion/vfox_${vfoxVersion}_windows_x86_64.zip"
    Step "Download vfox $vfoxVersion"
    curl.exe --retry 3 --retry-delay 5 --retry-all-errors --fail --silent --show-error --location --output $zip $url
    Assert ((Get-FileHash -Algorithm SHA256 $zip).Hash.ToLowerInvariant() -eq $vfoxSha256) 'vfox archive checksum mismatch'

    $extract = Join-Path $work 'extract'
    New-Item -ItemType Directory -Force -Path $extract | Out-Null
    # Expand-Archive rather than tar: CI runners also put Git's GNU tar on the
    # PATH, which reads the colon of a drive letter as a remote host.
    Expand-Archive -Path $zip -DestinationPath $extract -Force
    $found = Get-ChildItem -Path $extract -Recurse -Filter 'vfox.exe' | Select-Object -First 1
    Assert ($null -ne $found) 'vfox.exe not found in the release archive'
    Copy-Item -Path $found.FullName -Destination $vfoxExe
}
$env:PATH = "$work;$env:PATH"
Step "vfox $(& $vfoxExe --version)"

# Package the plugin from the repository and add it from the local archive.
$pluginZip = Join-Path $work 'dotnet-plugin.zip'
Step 'Register the local dotnet plugin'
Compress-Archive -Path (Join-Path $repo 'metadata.lua'), (Join-Path $repo 'hooks'), (Join-Path $repo 'lib') -DestinationPath $pluginZip -Force
& $vfoxExe add dotnet --source $pluginZip
Assert ($LASTEXITCODE -eq 0) 'vfox add dotnet failed'

Step "vfox search dotnet $version"
& $vfoxExe search dotnet $version
Assert ($LASTEXITCODE -eq 0) 'vfox search dotnet failed'

Step "vfox install dotnet@$version"
& $vfoxExe install "dotnet@$version"
Assert ($LASTEXITCODE -eq 0) 'vfox install dotnet failed'

# vfox needs its shell hook for `use`; env -s applies the selection to this
# process, which has no interactive prompt to do it.
Step 'Activate vfox'
Invoke-Expression -Command (& $vfoxExe activate pwsh | Out-String)
& $vfoxExe use --global "dotnet@$version"
Assert ($LASTEXITCODE -eq 0) 'vfox use dotnet failed'
Invoke-Expression -Command (& $vfoxExe env -s pwsh | Out-String)

Step 'Verify the environment'
Assert (-not [string]::IsNullOrEmpty($env:DOTNET_ROOT)) 'DOTNET_ROOT is not set'
Assert (Test-Path $env:DOTNET_ROOT) "DOTNET_ROOT does not exist: $env:DOTNET_ROOT"
Write-Host "DOTNET_ROOT=$env:DOTNET_ROOT"
Step 'vfox current dotnet'
& $vfoxExe current dotnet

Step 'dotnet --version'
$actual = (& dotnet --version | Out-String).Trim()
Assert ($LASTEXITCODE -eq 0) 'dotnet --version failed'
Write-Host "dotnet --version = $actual"
$majorMinor = ($version -Split '\.')[0..1] -join '.'
Assert ($actual -like "$majorMinor.*") "expected $majorMinor.*, got $actual"

Step 'dotnet --list-sdks'
& dotnet --list-sdks
Assert ($LASTEXITCODE -eq 0) 'dotnet --list-sdks failed'

# Detection: a synthetic SDK under ~/.dotnet must be found by
# `vfox link --detect` and linked. The SDK installed above lives under
# ~/.vfox and is deliberately excluded from detection.
Step 'vfox link --detect -y dotnet'
$fakeHome = Join-Path $env:USERPROFILE '.dotnet'
New-Item -ItemType Directory -Force -Path (Join-Path $fakeHome 'sdk\6.0.428') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $fakeHome 'shared\Microsoft.NETCore.App\6.0.36') | Out-Null
New-Item -ItemType File -Force -Path (Join-Path $fakeHome 'dotnet.exe') | Out-Null
& $vfoxExe link --detect -y dotnet
Assert ($LASTEXITCODE -eq 0) 'vfox link --detect failed'
$listed = (& $vfoxExe list dotnet | Out-String)
Assert ($listed -match [regex]::Escape($fakeHome)) "linked SDK not listed: $listed"

Write-Host 'PASS: dotnet installed, detected and used through the vfox plugin on Windows'
