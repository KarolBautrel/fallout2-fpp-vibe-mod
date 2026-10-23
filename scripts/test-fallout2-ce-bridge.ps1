[CmdletBinding()]
param(
    [string] $EnginePath
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($EnginePath)) {
    $EnginePath = Join-Path $repositoryRoot 'engine\fallout2-ce'
}
$EnginePath = [System.IO.Path]::GetFullPath($EnginePath)

$mapSourcePath = Join-Path $EnginePath 'src\map.cc'
$mapSource = Get-Content -LiteralPath $mapSourcePath -Raw
if (-not $mapSource.Contains('char temp[COMPAT_MAX_PATH]') `
    -or -not $mapSource.Contains('snprintf(temp, sizeof(temp), "%s\\MAPS"')) {
    throw 'fallout2-ce map save path is not protected against long runtime paths.'
}

$testSource = Join-Path $repositoryRoot 'integration\fallout2-ce\tests'
$buildPath = Join-Path $repositoryRoot 'artifacts\build\fallout2-ce-bridge-contract'
$tracePath = Join-Path $repositoryRoot 'artifacts\fallout2-ce-bridge-contract.jsonl'

cmake -S $testSource -B $buildPath `
    -G 'Visual Studio 17 2022' -A x64 `
    "-DFALLOUT2_CE_SOURCE_DIR=$EnginePath"
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to configure the fallout2-ce bridge contract test.'
}

cmake --build $buildPath --config Release
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to build the fallout2-ce bridge contract test.'
}

$testExecutable = Join-Path $buildPath 'Release\fallout2_fpp_bridge_contract.exe'
& $testExecutable $tracePath
if ($LASTEXITCODE -ne 0) {
    throw "Bridge contract executable failed with exit code $LASTEXITCODE."
}

$events = @(Get-Content -LiteralPath $tracePath | ForEach-Object { $_ | ConvertFrom-Json })
if ($events.Count -ne 6) {
    throw "Expected 6 bridge events, found $($events.Count)."
}

$expectedEventNames = @('session_started', 'map_loaded', 'object_state', 'player_moved', 'interaction', 'object_state')
for ($index = 0; $index -lt $expectedEventNames.Count; $index++) {
    if ($events[$index].event -ne $expectedEventNames[$index]) {
        throw "Expected event $($expectedEventNames[$index]) at index $index, found $($events[$index].event)."
    }
    if ($events[$index].sequence -ne $index) {
        throw "Expected sequence $index, found $($events[$index].sequence)."
    }
    if ($events[$index].schema -ne 'fo2remix.bridge-v1') {
        throw "Unexpected schema at index $index."
    }
}

if ($events[1].map.name -ne 'AR"TEMPLE.MAP' -or $events[1].player.hex_index -ne 18492) {
    throw 'map_loaded payload failed validation.'
}
if (-not $events[2].snapshot `
    -or $events[2].target.instance_id -ne 17 `
    -or $events[2].state.open `
    -or -not $events[2].state.blocks_movement) {
    throw 'initial door snapshot failed validation.'
}
if ($events[3].player.rotation -ne 2) {
    throw 'player_moved payload failed validation.'
}
if ($events[4].target.instance_id -ne 17 -or $events[4].target.object_id -ne 16 -or $events[4].result -ne 0) {
    throw 'interaction payload failed validation.'
}
if ($events[5].snapshot `
    -or $events[5].target.instance_id -ne 17 `
    -or -not $events[5].state.open `
    -or $events[5].state.locked `
    -or $events[5].state.jammed `
    -or $events[5].state.blocks_movement) {
    throw 'object_state door payload failed validation.'
}

Write-Output "Bridge contract passed: $tracePath"
