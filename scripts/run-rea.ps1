[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $ReaArguments
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$nodeRoot = Join-Path $repositoryRoot 'artifacts\tools\runtime\node-v24.22.1-win-x64'
$nodeExecutable = Join-Path $nodeRoot 'node.exe'
$javaHome = Join-Path $repositoryRoot 'artifacts\tools\runtime\jdk-21.0.12.1+1'
$ghidraHome = Join-Path $repositoryRoot 'artifacts\tools\runtime\ghidra_12.1.4_PUBLIC'
$reaEntryPoint = Join-Path $repositoryRoot 'artifacts\tools\rea\node_modules\rea-agents\scripts\rea.mjs'

$requiredPaths = @(
    $nodeExecutable,
    (Join-Path $javaHome 'bin\java.exe'),
    (Join-Path $ghidraHome 'support\analyzeHeadless.bat'),
    $reaEntryPoint
)

foreach ($requiredPath in $requiredPaths) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Missing local REA toolchain component: $requiredPath. See docs/REA_INTEGRATION.md."
    }
}

$env:Path = "$nodeRoot;$javaHome\bin;$env:Path"
$env:JAVA_HOME = $javaHome
$env:GHIDRA_INSTALL_DIR = $ghidraHome
$env:REA_ANALYSIS_PROVIDER = 'ghidra'
$env:REA_GHIDRA_STARTUP_TIMEOUT_MS = '1800000'

& $nodeExecutable $reaEntryPoint @ReaArguments
exit $LASTEXITCODE
