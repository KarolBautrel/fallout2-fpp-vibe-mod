[CmdletBinding()]
param(
    [string] $EnginePath,
    [string] $GameDataPath = 'C:\Program Files (x86)\Steam\steamapps\common\Fallout 2',
    [string] $TracePath,
    [string] $RuntimePath
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($EnginePath)) {
    $EnginePath = Join-Path $repositoryRoot 'engine\fallout2-ce'
}
if ([string]::IsNullOrWhiteSpace($TracePath)) {
    $TracePath = Join-Path $repositoryRoot 'artifacts\fallout2-ce-state.jsonl'
}
if ([string]::IsNullOrWhiteSpace($RuntimePath)) {
    $RuntimePath = Join-Path $repositoryRoot 'artifacts\fallout2-ce-runtime'
}

$EnginePath = [System.IO.Path]::GetFullPath($EnginePath)
$GameDataPath = [System.IO.Path]::GetFullPath($GameDataPath)
$TracePath = [System.IO.Path]::GetFullPath($TracePath)
$RuntimePath = [System.IO.Path]::GetFullPath($RuntimePath)
$sourceExecutable = Join-Path $EnginePath 'out\build\windows-x64-vs2022\Release\fallout2-ce.exe'
$artifactsRoot = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot 'artifacts'))
$runtimePrefix = $artifactsRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

if (-not $RuntimePath.StartsWith($runtimePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "RuntimePath must be inside the ignored artifacts directory: $artifactsRoot"
}

foreach ($requiredPath in @(
    $sourceExecutable,
    $GameDataPath,
    (Join-Path $GameDataPath 'master.dat'),
    (Join-Path $GameDataPath 'critter.dat'),
    (Join-Path $GameDataPath 'patch000.dat')
)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Missing required path: $requiredPath"
    }
}

$traceDirectory = Split-Path -Parent $TracePath
if (-not (Test-Path -LiteralPath $traceDirectory)) {
    New-Item -ItemType Directory -Path $traceDirectory | Out-Null
}

$runtimeDataPath = Join-Path $RuntimePath 'data'
$runtimeMapsPath = Join-Path $runtimeDataPath 'maps'
foreach ($directory in @($RuntimePath, $runtimeDataPath, $runtimeMapsPath)) {
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }
}

$masterDatPath = Join-Path $GameDataPath 'master.dat'
$critterDatPath = Join-Path $GameDataPath 'critter.dat'
$patchTemplate = Join-Path $GameDataPath 'patch%03d.dat'
$runtimeExecutable = Join-Path $RuntimePath 'fallout2-ce.exe'
$runtimeConfigPath = Join-Path $RuntimePath 'fallout2.cfg'
$runtimeSfallConfigPath = Join-Path $RuntimePath 'ddraw.ini'

Copy-Item -LiteralPath $sourceExecutable -Destination $runtimeExecutable -Force

$runtimeConfig = @"
[debug]
mode=log

[system]
master_dat=$masterDatPath
master_patches=$runtimeDataPath
critter_dat=$critterDatPath
critter_patches=$runtimeDataPath
language=english
splash=0
"@
[System.IO.File]::WriteAllText($runtimeConfigPath, $runtimeConfig)

$runtimeSfallConfig = @"
[Misc]
PatchFile=$patchTemplate
"@
[System.IO.File]::WriteAllText($runtimeSfallConfigPath, $runtimeSfallConfig)

$previousBridgePath = $env:FALLOUT2_FPP_BRIDGE_PATH
try {
    $env:FALLOUT2_FPP_BRIDGE_PATH = $TracePath
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $runtimeExecutable
    $startInfo.WorkingDirectory = $RuntimePath
    $startInfo.UseShellExecute = $true
    $process = [System.Diagnostics.Process]::Start($startInfo)
} finally {
    $env:FALLOUT2_FPP_BRIDGE_PATH = $previousBridgePath
}

Write-Output "Started instrumented fallout2-ce (PID $($process.Id))."
Write-Output "Bridge trace: $TracePath"
Write-Output "Writable runtime: $RuntimePath"
Write-Output "Read-only game source: $GameDataPath"
