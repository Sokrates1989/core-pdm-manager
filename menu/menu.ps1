<#
.SYNOPSIS
Interactive menu entrypoint for core-pdm-manager.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ProjectRoot,
    [Parameter()]
    [string]$ConfigFile,
    [Parameter()]
    [ValidateSet("dependency-management", "initial-run", "diagnostics", "generate-files", "sanity-check", "ai-guidance")]
    [string]$Action
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$menuDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $menuDir
$scriptsDir = Join-Path $repoRoot "scripts"

. (Join-Path $scriptsDir "common.ps1")
. (Join-Path $menuDir "actions.ps1")

if (-not $PSBoundParameters.ContainsKey("ConfigFile") -or [string]::IsNullOrWhiteSpace($ConfigFile)) {
    $ConfigFile = $script:CorePdmManagerDefaultConfig
}

$resolvedProjectRoot = Get-PdmManagerProjectRoot -ProjectRoot $ProjectRoot
$resolvedConfigFile = $ConfigFile
if (-not [System.IO.Path]::IsPathRooted($resolvedConfigFile)) {
    $candidateFromCwd = Join-Path (Get-Location).Path $resolvedConfigFile
    if (Test-Path $candidateFromCwd) {
        $resolvedConfigFile = Resolve-PdmManagerPath -PathValue $candidateFromCwd
    } else {
        $resolvedConfigFile = Join-Path $repoRoot $resolvedConfigFile
    }
}

function Invoke-ActionByName {
    <#
    .SYNOPSIS
    Dispatches a named menu action.

    .PARAMETER ActionName
    Named action key.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ActionName
    )

    switch ($ActionName) {
        "dependency-management" { Invoke-DependencyManagementAction -ProjectRoot $resolvedProjectRoot -ConfigFile $resolvedConfigFile }
        "initial-run" { Invoke-InitialSetupAction -ProjectRoot $resolvedProjectRoot -ConfigFile $resolvedConfigFile }
        "diagnostics" { Invoke-DiagnosticsAction -ProjectRoot $resolvedProjectRoot -ConfigFile $resolvedConfigFile }
        "generate-files" { Invoke-GenerateDepFilesAction -ProjectRoot $resolvedProjectRoot -ConfigFile $resolvedConfigFile }
        "sanity-check" { Invoke-SanityCheckAction -ProjectRoot $resolvedProjectRoot -ConfigFile $resolvedConfigFile }
        "ai-guidance" { Invoke-AiGuidanceAction -ProjectRoot $resolvedProjectRoot -ConfigFile $resolvedConfigFile }
        default { throw "Unsupported action: $ActionName" }
    }
}

if (-not [string]::IsNullOrWhiteSpace($Action)) {
    Invoke-ActionByName -ActionName $Action
    exit 0
}

while ($true) {
    Write-Host ""
    Write-Host "========== Core PDM Manager Menu ==========" -ForegroundColor Yellow
    Write-Host "Project root: $resolvedProjectRoot" -ForegroundColor Gray
    Write-Host "Config file : $resolvedConfigFile" -ForegroundColor Gray
    Write-Host ""
    Write-Host "1) Open dependency management shell" -ForegroundColor Gray
    Write-Host "2) Initial setup (non-interactive install)" -ForegroundColor Gray
    Write-Host "3) Run diagnostics" -ForegroundColor Gray
    Write-Host "4) Generate dependency files" -ForegroundColor Gray
    Write-Host "5) Run sanity check" -ForegroundColor Gray
    Write-Host "6) Build AI solve guidance" -ForegroundColor Gray
    Write-Host "7) Exit" -ForegroundColor Gray
    Write-Host ""

    $choice = Read-Host "Choose option (1-7)"
    switch ($choice) {
        "1" { Invoke-DependencyManagementAction -ProjectRoot $resolvedProjectRoot -ConfigFile $resolvedConfigFile }
        "2" { Invoke-InitialSetupAction -ProjectRoot $resolvedProjectRoot -ConfigFile $resolvedConfigFile }
        "3" { Invoke-DiagnosticsAction -ProjectRoot $resolvedProjectRoot -ConfigFile $resolvedConfigFile }
        "4" { Invoke-GenerateDepFilesAction -ProjectRoot $resolvedProjectRoot -ConfigFile $resolvedConfigFile }
        "5" { Invoke-SanityCheckAction -ProjectRoot $resolvedProjectRoot -ConfigFile $resolvedConfigFile }
        "6" { Invoke-AiGuidanceAction -ProjectRoot $resolvedProjectRoot -ConfigFile $resolvedConfigFile }
        "7" {
            Write-Host "Exiting core-pdm-manager menu." -ForegroundColor Cyan
            exit 0
        }
        default {
            Write-Host "Invalid selection. Please choose 1-7." -ForegroundColor Yellow
        }
    }
}
