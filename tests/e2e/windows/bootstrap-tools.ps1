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

# Installs PowerShell 7 into the image. The zip extracts in seconds where an
# MSI installer took minutes; the machine PATH is set so the Go test's exec
# calls find pwsh.exe without a long environment dance.
$ErrorActionPreference = 'Stop'

$arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
$zip = Join-Path $env:TEMP 'pwsh.zip'
$url = "https://github.com/PowerShell/PowerShell/releases/download/v7.6.6/PowerShell-7.6.6-win-$arch.zip"
$home = 'C:\Program Files\PowerShell\7'

curl.exe --retry 3 --retry-delay 5 --retry-all-errors --fail --silent --show-error --location --output $zip $url
if ($LASTEXITCODE -ne 0) { throw 'FAIL: PowerShell download' }
New-Item -ItemType Directory -Force -Path $home | Out-Null
tar.exe -xf $zip -C $home
if ($LASTEXITCODE -ne 0) { throw 'FAIL: PowerShell extraction' }
Remove-Item -Force $zip
if (-not (Test-Path (Join-Path $home 'pwsh.exe'))) { throw 'FAIL: pwsh.exe missing' }

$machinePath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
[Environment]::SetEnvironmentVariable('PATH', "$machinePath;$home", 'Machine')
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1 -PropertyType DWORD -Force | Out-Null

Write-Host "PASS: installed PowerShell 7.6.6 ($arch)"
