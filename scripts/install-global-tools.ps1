[CmdletBinding()]
param(
    [string]$GodotPath = "$env:USERPROFILE\Desktop\Gierka\installers\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    throw 'Nie znaleziono winget. Zainstaluj lub napraw Microsoft App Installer.'
}

$packages = @()

if (-not (Get-Command cmake.exe -ErrorAction SilentlyContinue)) {
    $packages += @{ Id = 'Kitware.CMake'; Args = @() }
}

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$hasCppTools = Get-Command cl.exe -ErrorAction SilentlyContinue
if (-not $hasCppTools -and (Test-Path -LiteralPath $vswhere)) {
    $hasCppTools = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
}
if (-not $hasCppTools) {
    $packages += @{
        Id = 'Microsoft.VisualStudio.BuildTools'
        Args = @('--override', '--wait --quiet --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended')
    }
}

if (Test-Path -LiteralPath $GodotPath) {
    & $GodotPath --version
    if ($LASTEXITCODE -ne 0) {
        throw "Znaleziono Godota, ale test wersji nie powiódł się: $GodotPath"
    }
    Write-Host "Godot jest już dostępny: $GodotPath"
} elseif (-not (Get-Command godot.exe -ErrorAction SilentlyContinue)) {
    $packages += @{ Id = 'GodotEngine.GodotEngine'; Args = @() }
}

if (Get-Command py.exe -ErrorAction SilentlyContinue) {
    & py.exe --version
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'Python jest już zainstalowany; pomijam dodatkową wersję.'
    } else {
        $packages = @(@{ Id = 'Python.Python.3.13'; Args = @() }) + $packages
    }
} else {
    $packages = @(@{ Id = 'Python.Python.3.13'; Args = @() }) + $packages
}

foreach ($package in $packages) {
    $arguments = @(
        'install',
        '--id', $package.Id,
        '--exact',
        '--accept-package-agreements',
        '--accept-source-agreements'
    ) + $package.Args

    Write-Host "Instaluję $($package.Id)..."
    & winget.exe @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Instalacja $($package.Id) nie powiodła się (exit $LASTEXITCODE)."
    }
}

Write-Host 'Narzędzia zainstalowane. Otwórz nowy terminal, aby odświeżyć PATH.'

