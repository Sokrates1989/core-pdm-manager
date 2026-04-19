<#
.SYNOPSIS
Main entrypoint for interactive and initial-run dependency management.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ProjectRoot,
    [Parameter()]
    [string]$ConfigFile,
    [Parameter()]
    [switch]$InitialRun,
    [Parameter()]
    [switch]$NonInteractive,
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
        $resolvedConfigFile = (Get-PdmManagerAbsolutePath -PathValue $candidateFromCwd)
    } else {
        $resolvedConfigFile = (Get-PdmManagerAbsolutePath -PathValue $resolvedConfigFile -BasePath $script:CorePdmManagerRepoRoot)
    }
} else {
    $resolvedConfigFile = (Get-PdmManagerAbsolutePath -PathValue $resolvedConfigFile)
}

Write-PdmManagerMessage -Message "[core-pdm-manager] Project root: $resolvedProjectRoot" -Color Cyan
Write-PdmManagerMessage -Message "[core-pdm-manager] Config file: $resolvedConfigFile" -Color Cyan

Test-PdmManagerDocker
Ensure-PdmManagerConfigFile -ConfigFilePath $resolvedConfigFile

Write-PdmManagerMessage -Message "[core-pdm-manager] Effective config values:" -Color Cyan
Get-Content $resolvedConfigFile | ForEach-Object {
    $line = $_.Trim()
    if ([string]::IsNullOrWhiteSpace($line)) {
        return
    }
    if ($line.StartsWith('#')) {
        return
    }
    Write-PdmManagerMessage -Message "  $line" -Color Yellow
}

if (-not $InitialRun.IsPresent -and -not $NonInteractive.IsPresent) {
    $choice = Read-Host "Proceed with this configuration? (Y/n)"
    if ($choice -match '^[Nn]$') {
        Write-PdmManagerMessage -Message "Aborted by user." -Color Yellow
        exit 0
    }
}

$plainVersion = Get-PdmManagerPlainPythonVersion -PythonVersion (Get-PdmManagerPythonVersion -ProjectRoot $resolvedProjectRoot)
$env:PDM_MANAGER_PYTHON_VERSION = $plainVersion

if (-not $SkipBuild.IsPresent) {
    Write-PdmManagerMessage -Message "[core-pdm-manager] Building dependency-management image..." -Color Cyan
    $buildExit = Invoke-PdmManagerCompose -ProjectRoot $resolvedProjectRoot -ConfigFilePath $resolvedConfigFile -ComposeArgs @("build", "dev")
    if ($buildExit -ne 0) {
        throw "Docker compose build failed with exit code $buildExit"
    }
}

Write-PdmManagerMessage -Message "[core-pdm-manager] Running container-side setup..." -Color Cyan
$setupExit = Invoke-PdmManagerCompose -ProjectRoot $resolvedProjectRoot -ConfigFilePath $resolvedConfigFile -ComposeArgs @("run", "--rm", "dev", "/bin/bash", "/opt/core-pdm-manager/dev-setup.sh")
if ($setupExit -ne 0) {
    throw "Container setup failed with exit code $setupExit"
}

if ($InitialRun.IsPresent) {
    Write-PdmManagerMessage -Message "[core-pdm-manager] Running initial pdm install..." -Color Cyan
    $installExit = Invoke-PdmManagerCompose -ProjectRoot $resolvedProjectRoot -ConfigFilePath $resolvedConfigFile -ComposeArgs @("run", "--rm", "dev", "pdm", "install")
    if ($installExit -ne 0) {
        throw "pdm install failed with exit code $installExit"
    }
    Write-PdmManagerMessage -Message "[core-pdm-manager] Initial run completed successfully." -Color Green
    exit 0
}

Write-PdmManagerMessage -Message "[core-pdm-manager] Opening interactive shell in dependency manager container..." -Color Cyan
$interactiveExit = Invoke-PdmManagerCompose -ProjectRoot $resolvedProjectRoot -ConfigFilePath $resolvedConfigFile -ComposeArgs @("run", "--rm", "dev")
if ($interactiveExit -ne 0) {
    throw "Interactive container failed with exit code $interactiveExit"
}
