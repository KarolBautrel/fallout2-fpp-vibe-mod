[CmdletBinding()]
param(
    [string] $EnginePath,
    [string] $GameDataPath = 'C:\Program Files (x86)\Steam\steamapps\common\Fallout 2',
    [string] $TracePath
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($EnginePath)) {
    $EnginePath = Join-Path $repositoryRoot 'engine\fallout2-ce'
}
if ([string]::IsNullOrWhiteSpace($TracePath)) {
    $TracePath = Join-Path $repositoryRoot 'artifacts\fallout2-ce-state.jsonl'
}

$EnginePath = [System.IO.Path]::GetFullPath($EnginePath)
$GameDataPath = [System.IO.Path]::GetFullPath($GameDataPath)
$TracePath = [System.IO.Path]::GetFullPath($TracePath)
$executable = Join-Path $EnginePath 'out\build\windows-x64-vs2022\Release\fallout2-ce.exe'

foreach ($requiredPath in @($executable, $GameDataPath, (Join-Path $GameDataPath 'master.dat'))) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Missing required path: $requiredPath"
    }
}

$traceDirectory = Split-Path -Parent $TracePath
if (-not (Test-Path -LiteralPath $traceDirectory)) {
    New-Item -ItemType Directory -Path $traceDirectory | Out-Null
}

$previousBridgePath = $env:FALLOUT2_FPP_BRIDGE_PATH
try {
    $env:FALLOUT2_FPP_BRIDGE_PATH = $TracePath
    $process = Start-Process -FilePath $executable -WorkingDirectory $GameDataPath -PassThru
} finally {
    $env:FALLOUT2_FPP_BRIDGE_PATH = $previousBridgePath
}

Write-Output "Started instrumented fallout2-ce (PID $($process.Id))."
Write-Output "Bridge trace: $TracePath"
