[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

if (-not (Get-Command codex.exe -ErrorAction SilentlyContinue)) {
    throw 'Nie znaleziono codex.exe w PATH.'
}

codex plugin marketplace add rehan-remade/universal-modder
if ($LASTEXITCODE -ne 0) { throw 'Nie udało się dodać marketplace Universal Modder.' }

codex plugin add universal-modder@universal-modder
if ($LASTEXITCODE -ne 0) { throw 'Nie udało się zainstalować pluginu Universal Modder.' }

Write-Host 'Universal Modder zainstalowany. Uruchom nową sesję Codex, aby zobaczyć jego skille.'

