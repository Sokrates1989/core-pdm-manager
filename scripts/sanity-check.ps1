<#
.SYNOPSIS
Import-based sanity check runner for dependency integrity.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ProjectRoot,
    [Parameter()]
    [string]$ConfigFile,
    [Parameter()]
    [switch]$IncludeDev,
    [Parameter()]
    [switch]$SkipBuild,
    [Parameter()]
    [switch]$AutoAiGuidance
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

$reportFile = Join-Path $resolvedProjectRoot ".pdm-manager\reports\dependency-sanity-report.json"

Write-PdmManagerMessage -Message "[core-pdm-manager] Running sanity checks for: $resolvedProjectRoot" -Color Cyan
Test-PdmManagerDocker
Ensure-PdmManagerConfigFile -ConfigFilePath $resolvedConfigFile

if (-not $SkipBuild.IsPresent) {
    Write-PdmManagerMessage -Message "[core-pdm-manager] Building manager image..." -Color Cyan
    $buildExit = Invoke-PdmManagerCompose -ProjectRoot $resolvedProjectRoot -ConfigFilePath $resolvedConfigFile -ComposeArgs @("build", "dev")
    if ($buildExit -ne 0) {
        throw "docker compose build failed with exit code $buildExit"
    }
}

$installCommand = "pdm install"
if ($IncludeDev.IsPresent) {
    $installCommand = "pdm install --group :all"
}

Write-PdmManagerMessage -Message "[core-pdm-manager] Installing dependencies before sanity import checks..." -Color Cyan
$installExit = Invoke-PdmManagerCompose -ProjectRoot $resolvedProjectRoot -ConfigFilePath $resolvedConfigFile -ComposeArgs @("run", "--rm", "dev", "/bin/bash", "-lc", $installCommand)
if ($installExit -ne 0) {
    throw "Dependency installation failed with exit code $installExit"
}

Write-PdmManagerMessage -Message "[core-pdm-manager] Executing import probe suite..." -Color Cyan
$sanityArgs = @("run", "--rm", "dev", "python", "/opt/core-pdm-manager/internal/run_sanity_check.py", "--project-root", "/workspace", "--output", "/workspace/.pdm-manager/reports/dependency-sanity-report.json")
if ($IncludeDev.IsPresent) {
    $sanityArgs += "--include-dev"
}
$sanityExit = Invoke-PdmManagerCompose -ProjectRoot $resolvedProjectRoot -ConfigFilePath $resolvedConfigFile -ComposeArgs $sanityArgs

if ($sanityExit -eq 0) {
    Write-PdmManagerMessage -Message "[core-pdm-manager] Sanity check passed." -Color Green
    Write-PdmManagerMessage -Message "Report: $reportFile" -Color Green
    exit 0
}

if ($sanityExit -eq 2) {
    Write-PdmManagerMessage -Message "[core-pdm-manager] Sanity check found import failures." -Color Yellow
    Write-PdmManagerMessage -Message "Report: $reportFile" -Color Yellow

    if ($AutoAiGuidance.IsPresent) {
        Write-PdmManagerMessage -Message "[core-pdm-manager] Running AI guidance generator..." -Color Cyan
        & (Join-Path $scriptDir "ai-solve-guidance.ps1") -ProjectRoot $resolvedProjectRoot -ConfigFile $resolvedConfigFile -ReportFile $reportFile
    }

    exit 2
}

throw "Sanity check failed unexpectedly with exit code $sanityExit"
