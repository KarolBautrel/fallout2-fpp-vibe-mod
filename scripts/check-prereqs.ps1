[CmdletBinding()]
param(
    [string]$GodotPath = ''
)

$gamePath = 'C:\Program Files (x86)\Steam\steamapps\common\Fallout 2'
$requiredGameFiles = @('fallout2.exe', 'master.dat', 'critter.dat', 'patch000.dat')

function Find-Command {
    param(
        [Parameter(Mandatory)][string[]]$Names,
        [switch]$VerifyVersion
    )
    foreach ($name in $Names) {
        $command = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $command) { continue }
        if ($VerifyVersion) {
            & $command.Source --version *> $null
            if ($LASTEXITCODE -ne 0) { continue }
        }
        return $command.Source
    }
    return $null
}

function Find-VsCompiler {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere)) {
        return $null
    }

    $installationPath = & $vswhere `
        -latest `
        -products '*' `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -property installationPath
    if (-not $installationPath) {
        return $null
    }

    $compiler = Get-ChildItem `
        -LiteralPath (Join-Path $installationPath 'VC\Tools\MSVC') `
        -Filter cl.exe `
        -File `
        -Recurse `
        -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -like '*\bin\Hostx64\x64\cl.exe' } |
        Sort-Object FullName -Descending |
        Select-Object -First 1

    if ($compiler) {
        return $compiler.FullName
    }
    return $null
}

$gameFiles = foreach ($name in $requiredGameFiles) {
    $fullPath = Join-Path $gamePath $name
    [ordered]@{ name = $name; exists = Test-Path -LiteralPath $fullPath }
}

$detectedGodot = Find-Command @('godot.exe', 'godot4.exe', 'Godot_v4*.exe') -VerifyVersion
if (-not $detectedGodot -and $GodotPath -and (Test-Path -LiteralPath $GodotPath)) {
    & $GodotPath --version *> $null
    if ($LASTEXITCODE -eq 0) {
        $detectedGodot = (Get-Item -LiteralPath $GodotPath).FullName
    }
}

$compiler = Find-Command @('cl.exe', 'clang-cl.exe')
if (-not $compiler) {
    $compiler = Find-VsCompiler
}

$result = [ordered]@{
    git = Find-Command @('git.exe') -VerifyVersion
    python = Find-Command @('python.exe', 'py.exe') -VerifyVersion
    cmake = Find-Command @('cmake.exe') -VerifyVersion
    compiler = $compiler
    godot = $detectedGodot
    fallout2_path = $gamePath
    fallout2_exists = Test-Path -LiteralPath $gamePath
    fallout2_files = $gameFiles
}

$result | ConvertTo-Json -Depth 4

if (-not $result.git -or -not $result.python -or -not $result.cmake -or -not $result.compiler -or -not $result.godot -or -not $result.fallout2_exists -or ($gameFiles.exists -contains $false)) {
    exit 1
}

