<#
.SYNOPSIS
Action handlers for core-pdm-manager menu.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:MenuDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:RepoRoot = Split-Path -Parent $script:MenuDir
$script:ScriptsDir = Join-Path $script:RepoRoot "scripts"

function Invoke-DependencyManagementAction {
    <#
    .SYNOPSIS
    Opens interactive dependency-management shell.

    .PARAMETER ProjectRoot
    Target project root.

    .PARAMETER ConfigFile
    Config env file path.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$ConfigFile
    )

    & (Join-Path $script:ScriptsDir "pdm-manager.ps1") -ProjectRoot $ProjectRoot -ConfigFile $ConfigFile
}

function Invoke-InitialSetupAction {
    <#
    .SYNOPSIS
    Executes initial dependency setup in non-interactive mode.

    .PARAMETER ProjectRoot
    Target project root.

    .PARAMETER ConfigFile
    Config env file path.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$ConfigFile
    )

    & (Join-Path $script:ScriptsDir "pdm-manager.ps1") -ProjectRoot $ProjectRoot -ConfigFile $ConfigFile -InitialRun -NonInteractive
}

function Invoke-DiagnosticsAction {
    <#
    .SYNOPSIS
    Runs diagnostics checks for dependency manager readiness.

    .PARAMETER ProjectRoot
    Target project root.

    .PARAMETER ConfigFile
    Config env file path.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$ConfigFile
    )

    & (Join-Path $script:ScriptsDir "diagnostics.ps1") -ProjectRoot $ProjectRoot -ConfigFile $ConfigFile
}

function Invoke-GenerateDepFilesAction {
    <#
    .SYNOPSIS
    Prompts for target artifacts and generates dependency files.

    .PARAMETER ProjectRoot
    Target project root.

    .PARAMETER ConfigFile
    Config env file path.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$ConfigFile
    )

    $defaultTargets = $env:PDM_MANAGER_DEFAULT_TARGETS
    if ([string]::IsNullOrWhiteSpace($defaultTargets)) {
        $defaultTargets = "pyproject.toml,pdm.lock"
    }

    Write-Host ""
    $targets = Read-Host "Targets (comma-separated) [$defaultTargets]"
    if ([string]::IsNullOrWhiteSpace($targets)) {
        $targets = $defaultTargets
    }

    $includePythonVersion = Read-Host "Write .python-version as well? (y/N)"
    if ($includePythonVersion -match '^[Yy]$') {
        if ($targets -notmatch '(?i)\.python-version') {
            $targets = "$targets,.python-version"
        }
    }

    & (Join-Path $script:ScriptsDir "generate-dep-files.ps1") -ProjectRoot $ProjectRoot -ConfigFile $ConfigFile -Targets $targets
}

function Invoke-SanityCheckAction {
    <#
    .SYNOPSIS
    Runs dependency import sanity checks.

    .PARAMETER ProjectRoot
    Target project root.

    .PARAMETER ConfigFile
    Config env file path.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$ConfigFile
    )

    $includeDev = Read-Host "Include dev dependencies in sanity check? (y/N)"
    if ($includeDev -match '^[Yy]$') {
        & (Join-Path $script:ScriptsDir "sanity-check.ps1") -ProjectRoot $ProjectRoot -ConfigFile $ConfigFile -IncludeDev
    } else {
        & (Join-Path $script:ScriptsDir "sanity-check.ps1") -ProjectRoot $ProjectRoot -ConfigFile $ConfigFile
    }
}

function Invoke-AiGuidanceAction {
    <#
    .SYNOPSIS
    Builds AI troubleshooting guidance and prints generated prompt.

    .PARAMETER ProjectRoot
    Target project root.

    .PARAMETER ConfigFile
    Config env file path.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$ConfigFile
    )

    $useExternalAi = (Read-Host "Use external AI provider lookup? (y/N)") -match '^[Yy]$'
    if ($useExternalAi) {
        $providerEndpoint = if ($env:PDM_MANAGER_AI_PROVIDER_ENDPOINT) { $env:PDM_MANAGER_AI_PROVIDER_ENDPOINT } else { "" }
        $providerModel = if ($env:PDM_MANAGER_AI_PROVIDER_MODEL) { $env:PDM_MANAGER_AI_PROVIDER_MODEL } else { "" }
        $providerApiKeyEnv = if ($env:PDM_MANAGER_AI_PROVIDER_API_KEY_ENV) { $env:PDM_MANAGER_AI_PROVIDER_API_KEY_ENV } else { "OPENAI_API_KEY" }
        $providerTimeoutSeconds = if ($env:PDM_MANAGER_AI_PROVIDER_TIMEOUT_SECONDS) { [int]$env:PDM_MANAGER_AI_PROVIDER_TIMEOUT_SECONDS } else { 45 }

        $inputEndpoint = Read-Host "Provider endpoint [$providerEndpoint]"
        if (-not [string]::IsNullOrWhiteSpace($inputEndpoint)) {
            $providerEndpoint = $inputEndpoint
        }

        $inputModel = Read-Host "Provider model [$providerModel]"
        if (-not [string]::IsNullOrWhiteSpace($inputModel)) {
            $providerModel = $inputModel
        }

        $inputApiKeyEnv = Read-Host "Provider API key env var [$providerApiKeyEnv]"
        if (-not [string]::IsNullOrWhiteSpace($inputApiKeyEnv)) {
            $providerApiKeyEnv = $inputApiKeyEnv
        }

        $inputTimeout = Read-Host "Provider timeout seconds [$providerTimeoutSeconds]"
        if (-not [string]::IsNullOrWhiteSpace($inputTimeout)) {
            $providerTimeoutSeconds = [int]$inputTimeout
        }

        & (Join-Path $script:ScriptsDir "ai-solve-guidance.ps1") -ProjectRoot $ProjectRoot -ConfigFile $ConfigFile -PrintPrompt -UseExternalAi -ProviderEndpoint $providerEndpoint -ProviderModel $providerModel -ProviderApiKeyEnv $providerApiKeyEnv -ProviderTimeoutSeconds $providerTimeoutSeconds
    } else {
        & (Join-Path $script:ScriptsDir "ai-solve-guidance.ps1") -ProjectRoot $ProjectRoot -ConfigFile $ConfigFile -PrintPrompt
    }
}
