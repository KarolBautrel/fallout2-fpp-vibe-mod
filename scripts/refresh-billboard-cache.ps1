param(
    [string]$GamePath = 'C:\Program Files (x86)\Steam\steamapps\common\Fallout 2'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$python = Join-Path $repositoryRoot '.venv\Scripts\python.exe'
$masterArchive = Join-Path $GamePath 'master.dat'
$critterArchive = Join-Path $GamePath 'critter.dat'
$artifactRoot = Join-Path $repositoryRoot 'artifacts'

foreach ($requiredPath in @($python, $masterArchive, $critterArchive)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Missing required file: $requiredPath"
    }
}

$previousPythonPath = $env:PYTHONPATH
try {
    $env:PYTHONPATH = Join-Path $repositoryRoot 'src'
    foreach ($mapName in @('artemple', 'arcaves')) {
        $scenePath = Join-Path $artifactRoot "$mapName.scene-v1.json"
        $cachePath = Join-Path $artifactRoot "art-cache\$mapName"
        & $python -m fo2remix scene-export `
            $masterArchive "maps\$mapName.map" $scenePath `
            --critter-archive $critterArchive
        if ($LASTEXITCODE -ne 0) {
            throw "Scene export failed for $mapName"
        }
        & $python -m fo2remix scene-art-cache `
            $masterArchive $scenePath $cachePath `
            --critter-archive $critterArchive --all-frames
        if ($LASTEXITCODE -ne 0) {
            throw "Art cache failed for $mapName"
        }
    }
} finally {
    $env:PYTHONPATH = $previousPythonPath
}

Write-Output "Refreshed billboard scenes and caches under $artifactRoot"
