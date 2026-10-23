[CmdletBinding()]
param(
    [string] $EnginePath,
    [switch] $CheckOnly
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($EnginePath)) {
    $EnginePath = Join-Path $repositoryRoot 'engine\fallout2-ce'
}
$EnginePath = [System.IO.Path]::GetFullPath($EnginePath)

$expectedCommit = 'e97087b9582f37075db347a89898887320753f8b'
$integrationRoot = Join-Path $repositoryRoot 'integration\fallout2-ce'
$patchPath = Join-Path $integrationRoot 'hooks.patch'
$bridgeSource = Join-Path $integrationRoot 'src\fpp_bridge.cc'
$bridgeHeader = Join-Path $integrationRoot 'src\fpp_bridge.h'

foreach ($requiredPath in @($EnginePath, $patchPath, $bridgeSource, $bridgeHeader)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Missing required path: $requiredPath"
    }
}

$actualCommit = (& git -C $EnginePath rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Unable to read fallout2-ce revision at $EnginePath"
}
if ($actualCommit -ne $expectedCommit) {
    throw "Expected fallout2-ce $expectedCommit, found $actualCommit"
}

$targetSource = Join-Path $EnginePath 'src\fpp_bridge.cc'
$targetHeader = Join-Path $EnginePath 'src\fpp_bridge.h'
$cmakeFile = Join-Path $EnginePath 'CMakeLists.txt'
$alreadyApplied = (Test-Path -LiteralPath $targetSource) `
    -and (Test-Path -LiteralPath $targetHeader) `
    -and (Select-String -LiteralPath $cmakeFile -SimpleMatch 'src/fpp_bridge.cc' -Quiet) `
    -and (Select-String -LiteralPath (Join-Path $EnginePath 'src\main.cc') -SimpleMatch 'fppBridgePollPlayer(gDude)' -Quiet) `
    -and (Select-String -LiteralPath (Join-Path $EnginePath 'src\map.cc') -SimpleMatch 'fppBridgeEmitMapLoaded' -Quiet) `
    -and (Select-String -LiteralPath (Join-Path $EnginePath 'src\map.cc') -SimpleMatch 'char temp[COMPAT_MAX_PATH]' -Quiet) `
    -and (Select-String -LiteralPath (Join-Path $EnginePath 'src\map.cc') -SimpleMatch 'snprintf(temp, sizeof(temp), "%s\\MAPS"' -Quiet) `
    -and (Select-String -LiteralPath (Join-Path $EnginePath 'src\object.cc') -SimpleMatch 'fppBridgeRegisterMapObject' -Quiet) `
    -and (Select-String -LiteralPath (Join-Path $EnginePath 'src\object.cc') -SimpleMatch 'fppBridgeRegisterDoor' -Quiet) `
    -and (Select-String -LiteralPath (Join-Path $EnginePath 'src\proto_instance.cc') -SimpleMatch 'fppBridgeEmitInteraction' -Quiet) `
    -and (Select-String -LiteralPath (Join-Path $EnginePath 'src\proto_instance.cc') -SimpleMatch 'fppBridgeEmitDoorState(door)' -Quiet)

if ($alreadyApplied) {
    if ((Get-FileHash -LiteralPath $targetSource).Hash -ne (Get-FileHash -LiteralPath $bridgeSource).Hash `
        -or (Get-FileHash -LiteralPath $targetHeader).Hash -ne (Get-FileHash -LiteralPath $bridgeHeader).Hash) {
        throw 'The checkout contains a different fallout2-ce bridge implementation.'
    }
    Write-Output "fallout2-ce bridge is already applied at $EnginePath"
    exit 0
}

& git -C $EnginePath apply --check --unidiff-zero $patchPath
if ($LASTEXITCODE -ne 0) {
    throw 'The bridge hook patch does not apply cleanly.'
}

if ($CheckOnly) {
    Write-Output "fallout2-ce bridge patch applies cleanly to $actualCommit"
    exit 0
}

& git -C $EnginePath apply --unidiff-zero $patchPath
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to apply the bridge hook patch.'
}

Copy-Item -LiteralPath $bridgeSource -Destination $targetSource
Copy-Item -LiteralPath $bridgeHeader -Destination $targetHeader

Write-Output "Applied fallout2-ce bridge to $EnginePath"
