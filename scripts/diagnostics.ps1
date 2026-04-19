<#
.SYNOPSIS
Diagnostic entrypoint for validating dependency manager readiness.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ProjectRoot,
    [Parameter()]
    [string]$ConfigFile,
    [Parameter()]
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "common.ps1")

if (-not $PSBoundParameters.ContainsKey("ConfigFile") -or [string]::IsNullOrWhiteSpace($ConfigFile)) {
    $ConfigFile = $script:CorePdmManagerDefaultConfig
}

$resolvedProjectRoot = Get-PdmManagerProjectRoot -ProjectRoot $ProjectRoot
$resolvedConfigFile = $ConfigFile

if (-not [System.IO.Path]::IsPathRooted($resolvedConfigFile)) {
    $candidateFromCwd = Join-Path (Get-Location).Path $resolvedConfigFile
    if (Test-Path $candidateFromCwd) {
        $resolvedConfigFile = Get-PdmManagerAbsolutePath -PathValue $candidateFromCwd
    } else {
        $resolvedConfigFile = Get-PdmManagerAbsolutePath -PathValue $resolvedConfigFile -BasePath $script:CorePdmManagerRepoRoot
    }
} else {
    $resolvedConfigFile = Get-PdmManagerAbsolutePath -PathValue $resolvedConfigFile
}

Write-PdmManagerMessage -Message "[core-pdm-manager] Diagnostics project root: $resolvedProjectRoot" -Color Cyan
Write-PdmManagerMessage -Message "[core-pdm-manager] Diagnostics config file: $resolvedConfigFile" -Color Cyan

Test-PdmManagerDocker
Ensure-PdmManagerConfigFile -ConfigFilePath $resolvedConfigFile

if (-not $SkipBuild.IsPresent) {
    Write-PdmManagerMessage -Message "[core-pdm-manager] Building manager image for diagnostics..." -Color Cyan
    $buildExit = Invoke-PdmManagerCompose -ProjectRoot $resolvedProjectRoot -ConfigFilePath $resolvedConfigFile -ComposeArgs @("build", "dev")
    if ($buildExit -ne 0) {
        throw "docker compose build failed with exit code $buildExit"
    }
}

Write-PdmManagerMessage -Message "[core-pdm-manager] Running container toolchain checks..." -Color Cyan
$toolCheckExit = Invoke-PdmManagerCompose -ProjectRoot $resolvedProjectRoot -ConfigFilePath $resolvedConfigFile -ComposeArgs @("run", "--rm", "dev", "/bin/bash", "-lc", "python --version && pdm --version && uv --version && poetry --version && pipenv --version")
if ($toolCheckExit -ne 0) {
    throw "Toolchain diagnostics failed with exit code $toolCheckExit"
}

$pyprojectPath = Join-Path $resolvedProjectRoot "pyproject.toml"
if (Test-Path $pyprojectPath) {
    Write-PdmManagerMessage -Message "[core-pdm-manager] pyproject.toml detected; validating lock state..." -Color Cyan
    $lockExit = Invoke-PdmManagerCompose -ProjectRoot $resolvedProjectRoot -ConfigFilePath $resolvedConfigFile -ComposeArgs @("run", "--rm", "dev", "pdm", "lock", "--check")
    if ($lockExit -eq 0) {
        Write-PdmManagerMessage -Message "[OK] pdm.lock is up-to-date." -Color Green
    } else {
        Write-PdmManagerMessage -Message "[WARN] pdm.lock appears out of date. Run generate-dep-files or pdm lock." -Color Yellow
    }
} else {
    Write-PdmManagerMessage -Message "[WARN] pyproject.toml missing in project root." -Color Yellow
}

foreach ($fileName in @("pyproject.toml", "pdm.lock", "requirements.txt", "Pipfile", "poetry.lock", "uv.lock", ".python-version")) {
    $filePath = Join-Path $resolvedProjectRoot $fileName
    if (Test-Path $filePath) {
        Write-PdmManagerMessage -Message "[OK] $fileName exists" -Color Green
    } else {
        Write-PdmManagerMessage -Message "[INFO] $fileName not found" -Color Yellow
    }
}

Write-PdmManagerMessage -Message "[core-pdm-manager] Diagnostics completed." -Color Green
