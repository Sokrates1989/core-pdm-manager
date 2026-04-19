<#
.SYNOPSIS
Shared helper functions for core-pdm-manager PowerShell scripts.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:CorePdmManagerScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:CorePdmManagerRepoRoot = Split-Path -Parent $script:CorePdmManagerScriptDir
$script:CorePdmManagerComposeFile = Join-Path $script:CorePdmManagerRepoRoot "docker\docker-compose.pdm-manager.yml"
$script:CorePdmManagerDefaultConfig = Join-Path $script:CorePdmManagerRepoRoot "config\config.env"

function Write-PdmManagerMessage {
    <#
    .SYNOPSIS
    Writes a colorized message for core-pdm-manager scripts.

    .PARAMETER Message
    The message text to print.

    .PARAMETER Color
    The foreground color.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter()]
        [string]$Color = "White"
    )

    Write-Host $Message -ForegroundColor $Color
}

function Resolve-PdmManagerPath {
    <#
    .SYNOPSIS
    Resolves a path to an absolute path.

    .PARAMETER PathValue
    The path value to resolve.

    .OUTPUTS
    string
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue
    )

    $resolved = Resolve-Path -LiteralPath $PathValue -ErrorAction SilentlyContinue
    if (-not $resolved) {
        throw "Could not resolve path: $PathValue"
    }

    return $resolved.Path
}

function Get-PdmManagerAbsolutePath {
    <#
    .SYNOPSIS
    Returns an absolute path even when the target does not exist yet.

    .PARAMETER PathValue
    The path value to normalize.

    .PARAMETER BasePath
    Optional base path for relative values.

    .OUTPUTS
    string
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue,
        [Parameter()]
        [string]$BasePath = (Get-Location).Path
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        throw "PathValue must not be empty."
    }

    if (Test-Path $PathValue) {
        return (Resolve-PdmManagerPath -PathValue $PathValue)
    }

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $PathValue))
}

function Get-PdmManagerProjectRoot {
    <#
    .SYNOPSIS
    Determines the target project root.

    .PARAMETER ProjectRoot
    Optional explicit project root.

    .OUTPUTS
    string
    #>
    param(
        [Parameter()]
        [string]$ProjectRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($ProjectRoot)) {
        return (Resolve-PdmManagerPath -PathValue $ProjectRoot)
    }

    if (-not [string]::IsNullOrWhiteSpace($env:PDM_MANAGER_PROJECT_ROOT)) {
        return (Resolve-PdmManagerPath -PathValue $env:PDM_MANAGER_PROJECT_ROOT)
    }

    return (Get-Location).Path
}

function Get-PdmManagerPythonVersion {
    <#
    .SYNOPSIS
    Resolves Python version to use for container builds.

    .PARAMETER ProjectRoot
    Target project root.

    .OUTPUTS
    string
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($env:PYTHON_VERSION)) {
        return $env:PYTHON_VERSION
    }

    $envFile = Join-Path $ProjectRoot ".env"
    if (Test-Path $envFile) {
        $line = Get-Content $envFile | Where-Object { $_ -match '^PYTHON_VERSION=' } | Select-Object -Last 1
        if ($line) {
            return ($line -replace '^PYTHON_VERSION=', '').Trim()
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($env:PDM_MANAGER_DEFAULT_PYTHON_VERSION)) {
        return $env:PDM_MANAGER_DEFAULT_PYTHON_VERSION
    }

    return "3.13-slim"
}

function Get-PdmManagerPlainPythonVersion {
    <#
    .SYNOPSIS
    Converts image tag-like Python version to plain semantic version.

    .PARAMETER PythonVersion
    Python version string.

    .OUTPUTS
    string
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PythonVersion
    )

    return ($PythonVersion -replace '-slim$', '')
}

function Import-PdmManagerEnvFile {
    <#
    .SYNOPSIS
    Loads key/value variables from an env file into process environment.

    .PARAMETER EnvFilePath
    Path to env file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$EnvFilePath
    )

    if (-not (Test-Path $EnvFilePath)) {
        return
    }

    foreach ($line in Get-Content $EnvFilePath) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            continue
        }
        if ($trimmed.StartsWith('#')) {
            continue
        }
        if ($trimmed -notmatch '=') {
            continue
        }

        $parts = $trimmed.Split('=', 2)
        $key = $parts[0].Trim()
        $value = $parts[1].Trim().Trim('"').Trim("'")
        [Environment]::SetEnvironmentVariable($key, $value, 'Process')
    }
}

function Ensure-PdmManagerConfigFile {
    <#
    .SYNOPSIS
    Ensures a config file exists, creating from template if necessary.

    .PARAMETER ConfigFilePath
    Path to config file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigFilePath
    )

    if (Test-Path $ConfigFilePath) {
        return
    }

    $example = Join-Path $script:CorePdmManagerRepoRoot "config\config.env.example"
    if (-not (Test-Path $example)) {
        throw "Missing config file and template: $ConfigFilePath"
    }

    $targetDir = Split-Path -Parent $ConfigFilePath
    if (-not (Test-Path $targetDir)) {
        New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
    }

    Copy-Item $example $ConfigFilePath -Force
    Write-PdmManagerMessage -Message "[core-pdm-manager] Created missing config file from template: $ConfigFilePath" -Color Yellow
}

function Test-PdmManagerDocker {
    <#
    .SYNOPSIS
    Verifies Docker and docker compose availability.
    #>
    param()

    try {
        $null = & docker --version 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Docker CLI not available"
        }
    } catch {
        throw "Docker CLI not available. Install Docker Desktop first."
    }

    try {
        $null = & docker info 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Docker daemon is not running"
        }
    } catch {
        throw "Docker daemon is not running."
    }

    try {
        $null = & docker compose version 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "docker compose unavailable"
        }
    } catch {
        throw "docker compose is unavailable."
    }

    Write-PdmManagerMessage -Message "[OK] Docker and docker compose are available." -Color Green
}

function Ensure-PdmManagerProjectLayout {
    <#
    .SYNOPSIS
    Ensures required output directories exist in target project root.

    .PARAMETER ProjectRoot
    Target project root.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    if (-not (Test-Path $ProjectRoot)) {
        throw "Project root does not exist: $ProjectRoot"
    }

    New-Item -Path (Join-Path $ProjectRoot ".pdm-manager\tmp") -ItemType Directory -Force | Out-Null
    New-Item -Path (Join-Path $ProjectRoot ".pdm-manager\reports") -ItemType Directory -Force | Out-Null
}

function Get-PdmManagerUid {
    <#
    .SYNOPSIS
    Returns UID for Linux container mapping.

    .OUTPUTS
    string
    #>
    param()

    if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
        return "1000"
    }

    try {
        $uid = (& id -u).Trim()
        if (-not [string]::IsNullOrWhiteSpace($uid)) {
            return $uid
        }
    } catch {
    }

    return "1000"
}

function Get-PdmManagerGid {
    <#
    .SYNOPSIS
    Returns GID for Linux container mapping.

    .OUTPUTS
    string
    #>
    param()

    if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
        return "1000"
    }

    try {
        $gid = (& id -g).Trim()
        if (-not [string]::IsNullOrWhiteSpace($gid)) {
            return $gid
        }
    } catch {
    }

    return "1000"
}

function Invoke-PdmManagerCompose {
    <#
    .SYNOPSIS
    Runs docker compose using the core-pdm-manager compose file.

    .PARAMETER ProjectRoot
    Target host project root.

    .PARAMETER ConfigFilePath
    Path to config env file.

    .PARAMETER ComposeArgs
    Remaining docker compose arguments.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$ConfigFilePath,
        [Parameter(Mandatory = $true)]
        [string[]]$ComposeArgs
    )

    Ensure-PdmManagerProjectLayout -ProjectRoot $ProjectRoot
    Ensure-PdmManagerConfigFile -ConfigFilePath $ConfigFilePath
    Import-PdmManagerEnvFile -EnvFilePath $ConfigFilePath

    $env:PDM_MANAGER_PROJECT_ROOT = $ProjectRoot
    $env:PDM_MANAGER_UID = Get-PdmManagerUid
    $env:PDM_MANAGER_GID = Get-PdmManagerGid
    $env:PYTHON_VERSION = Get-PdmManagerPythonVersion -ProjectRoot $ProjectRoot

    & docker compose -f $script:CorePdmManagerComposeFile @ComposeArgs | Out-Host
    return $LASTEXITCODE
}

function ConvertFrom-PdmManagerCsvTargets {
    <#
    .SYNOPSIS
    Converts comma-separated target values to an array.

    .PARAMETER CsvTargets
    Comma-separated string.

    .OUTPUTS
    string[]
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$CsvTargets
    )

    $targets = @()
    foreach ($item in $CsvTargets.Split(',')) {
        $trimmed = $item.Trim()
        if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
            $targets += $trimmed
        }
    }

    return $targets
}
