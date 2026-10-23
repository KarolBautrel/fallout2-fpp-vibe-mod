[CmdletBinding()]
param(
    [string]$Python = 'python',
    [string]$EngineRepository = 'https://github.com/alexbatalov/fallout2-ce.git',
    [switch]$InstallDependencies,
    [switch]$SkipEngine
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$venv = Join-Path $root '.venv'
$engine = Join-Path $root 'engine\fallout2-ce'
$privateTemp = Join-Path $root '.tmp'

function Assert-LastExitCode {
    param([Parameter(Mandatory)][string]$Operation)
    if ($LASTEXITCODE -ne 0) {
        throw "$Operation nie powiodło się (exit $LASTEXITCODE)."
    }
}

if (-not (Get-Command $Python -ErrorAction SilentlyContinue)) {
    throw "Nie znaleziono polecenia '$Python'. Zainstaluj globalny Python 3.13 i uruchom ponownie."
}

New-Item -ItemType Directory -Path $privateTemp -Force | Out-Null
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
$env:TEMP = $privateTemp
$env:TMP = $privateTemp

try {
    $venvPython = Join-Path $venv 'Scripts\python.exe'
    if (-not (Test-Path -LiteralPath $venvPython)) {
        & $Python -m venv --without-pip --system-site-packages $venv
        Assert-LastExitCode 'Tworzenie .venv'
    }

    if ($InstallDependencies) {
        & $venvPython -m pip install --editable "$root[dev]"
        Assert-LastExitCode 'Instalacja zależności projektu'
    }

    if (-not $SkipEngine -and -not (Test-Path -LiteralPath (Join-Path $engine '.git'))) {
        git clone --filter=blob:none $EngineRepository $engine
        Assert-LastExitCode 'Klonowanie fallout2-ce'
    }

    Write-Host "Gotowe: $venv"
    if (Test-Path -LiteralPath (Join-Path $engine '.git')) {
        Write-Host "Silnik: $engine"
    } elseif ($SkipEngine) {
        Write-Host 'Pominięto klonowanie silnika.'
    }
}
finally {
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
}

