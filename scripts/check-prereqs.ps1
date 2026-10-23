[CmdletBinding()]
param()

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

$gameFiles = foreach ($name in $requiredGameFiles) {
    $fullPath = Join-Path $gamePath $name
    [ordered]@{ name = $name; exists = Test-Path -LiteralPath $fullPath }
}

$result = [ordered]@{
    git = Find-Command @('git.exe') -VerifyVersion
    python = Find-Command @('python.exe', 'py.exe') -VerifyVersion
    cmake = Find-Command @('cmake.exe') -VerifyVersion
    compiler = Find-Command @('cl.exe', 'clang-cl.exe')
    godot = Find-Command @('godot.exe', 'godot4.exe', 'Godot_v4*.exe') -VerifyVersion
    fallout2_path = $gamePath
    fallout2_exists = Test-Path -LiteralPath $gamePath
    fallout2_files = $gameFiles
}

$result | ConvertTo-Json -Depth 4

if (-not $result.git -or -not $result.python -or -not $result.cmake -or -not $result.compiler -or -not $result.godot -or -not $result.fallout2_exists -or ($gameFiles.exists -contains $false)) {
    exit 1
}

