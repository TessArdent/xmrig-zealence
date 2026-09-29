# Builds XMRig from source with the developer donation minimum lowered to 0%, so Zealence's
# donation setting can go down to 0. XMRig is GPL-3.0; src/donate.h is where its authors expect
# self-builders to change this.
#
# Needs git, CMake, Ninja and Visual Studio (2022 or newer) with the C++ desktop tools.
# Output: xmrig.exe + WinRing0x64.sys (for the MSR mod) + a default config.json in $OutDir.
param(
    [string]$Version = "6.26.0",
    [string]$WorkDir = (Join-Path (Split-Path (Split-Path $PSScriptRoot)) "xmrig-build"),
    [string]$OutDir = (Join-Path $env:USERPROFILE "xmrig\xmrig-$Version-zealence")
)
$ErrorActionPreference = 'Stop'
$src = Join-Path $WorkDir "xmrig-$Version"
$deps = Join-Path $WorkDir "xmrig-deps"
New-Item -ItemType Directory -Force $WorkDir | Out-Null

function Invoke-Checked([string]$exe) {
    # git and cmake write progress to stderr; Windows PowerShell would turn that into a terminating error.
    $ErrorActionPreference = 'Continue'
    & $exe @args 2>&1 | ForEach-Object { "$_" }
    if ($LASTEXITCODE) { throw "$exe $($args -join ' ') failed with exit code $LASTEXITCODE" }
}

# 1. Sources: the tagged XMRig release and XMRig's prebuilt Windows dependencies (libuv, OpenSSL, hwloc).
if (-not (Test-Path $src)) { Invoke-Checked git clone --depth 1 --branch "v$Version" https://github.com/xmrig/xmrig.git $src }
if (-not (Test-Path $deps)) { Invoke-Checked git clone --depth 1 https://github.com/xmrig/xmrig-deps.git $deps }
$depsLib = Get-ChildItem $deps -Directory -Filter 'msvc*' | Sort-Object Name -Descending | Select-Object -First 1
if (-not $depsLib) { throw "No msvc* folder in $deps" }
$depsLib = Join-Path $depsLib.FullName "x64"

# 2. Donation: default and minimum 0%.
$donate = Join-Path $src "src\donate.h"
$text = Get-Content $donate -Raw
$patched = $text -replace 'kDefaultDonateLevel\s*=\s*\d+', 'kDefaultDonateLevel = 0' -replace 'kMinimumDonateLevel\s*=\s*\d+', 'kMinimumDonateLevel = 0'
if ($patched -notmatch 'kDefaultDonateLevel = 0' -or $patched -notmatch 'kMinimumDonateLevel = 0') { throw "Couldn't patch $donate" }
if ($patched -ne $text) { [IO.File]::WriteAllText($donate, $patched) }

# 3. MSVC environment (x64), then configure and build with Ninja.
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw "Visual Studio with the C++ x64 tools wasn't found." }
$vcvars = & {
    $ErrorActionPreference = 'Continue' # vcvars64.bat prints harmless warnings to stderr
    cmd /c "`"$vs\VC\Auxiliary\Build\vcvars64.bat`" >nul 2>nul && set"
}
$vcvars | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2]) }
}
if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) { throw "Couldn't load the MSVC x64 environment from $vs" }

$build = Join-Path $src "build"
Invoke-Checked cmake -S $src -B $build -G Ninja -DCMAKE_BUILD_TYPE=Release "-DXMRIG_DEPS=$depsLib"

# The post-build step copies WinRing0x64.sys (the MSR driver). Windows Defender and the vulnerable
# driver blocklist often block that file, which fails the build even though xmrig.exe linked fine.
$started = Get-Date
$ErrorActionPreference = 'Continue'
$output = & cmake --build $build 2>&1 | ForEach-Object { "$_" }
$code = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
$output | Select-Object -Last 5
$exe = Join-Path $build "xmrig.exe"
if ($code) {
    $linked = (Test-Path $exe) -and (Get-Item $exe).LastWriteTime -ge $started
    if (-not ($linked -and ($output -match 'WinRing0x64\.sys'))) { throw "cmake --build failed with exit code $code" }
    Write-Warning "xmrig.exe built, but copying WinRing0x64.sys was blocked (usually Windows Defender). The MSR mod may not work."
}

# 4. Package next to the official layout.
New-Item -ItemType Directory -Force $OutDir | Out-Null
Copy-Item $exe $OutDir -Force
try { Copy-Item (Join-Path $src "bin\WinRing0\WinRing0x64.sys") $OutDir -Force }
catch { Write-Warning "Couldn't copy WinRing0x64.sys ($($_.Exception.Message)). XMRig will mine without the MSR mod." }
Copy-Item (Join-Path $src "src\config.json") $OutDir -Force
& (Join-Path $OutDir "xmrig.exe") --version | Select-Object -First 1
Get-ChildItem $OutDir
