[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    throw 'Nie znaleziono winget. Zainstaluj lub napraw Microsoft App Installer.'
}

$packages = @(
    @{ Id = 'Kitware.CMake'; Args = @() },
    @{
        Id = 'Microsoft.VisualStudio.2022.BuildTools'
        Args = @('--override', '--wait --quiet --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended')
    },
    @{ Id = 'GodotEngine.GodotEngine'; Args = @() }
)

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

