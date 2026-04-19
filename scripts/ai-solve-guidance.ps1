<#
.SYNOPSIS
Build AI troubleshooting guidance from sanity report artifacts.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ProjectRoot,
    [Parameter()]
    [string]$ConfigFile,
    [Parameter()]
    [string]$ReportFile,
    [Parameter()]
    [switch]$UseExternalAi,
    [Parameter()]
    [string]$ProviderEndpoint,
    [Parameter()]
    [string]$ProviderModel,
    [Parameter()]
    [string]$ProviderApiKeyEnv,
    [Parameter()]
    [int]$ProviderTimeoutSeconds,
    [Parameter()]
    [switch]$PrintPrompt
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

if ([string]::IsNullOrWhiteSpace($ReportFile)) {
    $ReportFile = Join-Path $resolvedProjectRoot ".pdm-manager\reports\dependency-sanity-report.json"
} else {
    $ReportFile = Get-PdmManagerAbsolutePath -PathValue $ReportFile -BasePath (Get-Location).Path
}

if (-not ($ReportFile.StartsWith($resolvedProjectRoot, [System.StringComparison]::OrdinalIgnoreCase))) {
    throw "Report file must be inside project root: $resolvedProjectRoot"
}

if (-not (Test-Path $ReportFile)) {
    throw "Sanity report not found: $ReportFile`nRun sanity-check.ps1 first."
}

$guidanceFile = Join-Path $resolvedProjectRoot ".pdm-manager\reports\ai-solve-guidance.md"
$promptFile = Join-Path $resolvedProjectRoot ".pdm-manager\reports\ai-solve-prompt.txt"
$providerOutputFile = Join-Path $resolvedProjectRoot ".pdm-manager\reports\ai-provider-response.txt"

Test-PdmManagerDocker
Ensure-PdmManagerConfigFile -ConfigFilePath $resolvedConfigFile

$providerMode = "none"
if ([string]::IsNullOrWhiteSpace($ProviderEndpoint)) {
    $ProviderEndpoint = $env:PDM_MANAGER_AI_PROVIDER_ENDPOINT
}
if ([string]::IsNullOrWhiteSpace($ProviderModel)) {
    $ProviderModel = $env:PDM_MANAGER_AI_PROVIDER_MODEL
}
if ([string]::IsNullOrWhiteSpace($ProviderApiKeyEnv)) {
    $ProviderApiKeyEnv = if ([string]::IsNullOrWhiteSpace($env:PDM_MANAGER_AI_PROVIDER_API_KEY_ENV)) { "OPENAI_API_KEY" } else { $env:PDM_MANAGER_AI_PROVIDER_API_KEY_ENV }
}
if ($ProviderTimeoutSeconds -le 0) {
    $ProviderTimeoutSeconds = if ($env:PDM_MANAGER_AI_PROVIDER_TIMEOUT_SECONDS) { [int]$env:PDM_MANAGER_AI_PROVIDER_TIMEOUT_SECONDS } else { 45 }
}

if ($UseExternalAi.IsPresent) {
    $providerMode = "openai_compatible"
    if ([string]::IsNullOrWhiteSpace($ProviderEndpoint)) {
        throw "Missing provider endpoint. Set -ProviderEndpoint or PDM_MANAGER_AI_PROVIDER_ENDPOINT."
    }
    if ([string]::IsNullOrWhiteSpace($ProviderModel)) {
        throw "Missing provider model. Set -ProviderModel or PDM_MANAGER_AI_PROVIDER_MODEL."
    }
    Write-PdmManagerMessage -Message "[WARN] External AI mode enabled. Network call will be attempted." -Color Yellow
}

$relativeReportPath = [System.IO.Path]::GetRelativePath($resolvedProjectRoot, $ReportFile)
$containerReportPath = "/workspace/$($relativeReportPath -replace '\\','/')"

Write-PdmManagerMessage -Message "[core-pdm-manager] Generating AI guidance markdown and prompt artifacts..." -Color Cyan

$guidanceCmdArgs = @(
    "run", "--rm", "dev", "python", "/opt/core-pdm-manager/internal/build_ai_guidance.py",
    "--report", $containerReportPath,
    "--output", "/workspace/.pdm-manager/reports/ai-solve-guidance.md",
    "--prompt-output", "/workspace/.pdm-manager/reports/ai-solve-prompt.txt",
    "--provider-mode", $providerMode
)

if ($providerMode -ne "none") {
    $guidanceCmdArgs += @("--provider-endpoint", $ProviderEndpoint)
    $guidanceCmdArgs += @("--provider-model", $ProviderModel)
    $guidanceCmdArgs += @("--provider-api-key-env", $ProviderApiKeyEnv)
    $guidanceCmdArgs += @("--provider-timeout-seconds", "$ProviderTimeoutSeconds")
    $guidanceCmdArgs += @("--provider-output", "/workspace/.pdm-manager/reports/ai-provider-response.txt")
}

$exitCode = Invoke-PdmManagerCompose -ProjectRoot $resolvedProjectRoot -ConfigFilePath $resolvedConfigFile -ComposeArgs $guidanceCmdArgs
if ($exitCode -ne 0) {
    throw "Guidance generation failed with exit code $exitCode"
}

Write-PdmManagerMessage -Message "[OK] Guidance file: $guidanceFile" -Color Green
Write-PdmManagerMessage -Message "[OK] Prompt file: $promptFile" -Color Green
if ($UseExternalAi.IsPresent) {
    Write-PdmManagerMessage -Message "[OK] Provider output file: $providerOutputFile" -Color Green
}

if ($PrintPrompt.IsPresent) {
    Write-PdmManagerMessage -Message "========== AI SOLVE PROMPT ==========" -Color Cyan
    Get-Content $promptFile
    Write-PdmManagerMessage -Message "=====================================" -Color Cyan
}
