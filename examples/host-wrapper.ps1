<#
.SYNOPSIS
Example host-repo wrapper script for core-pdm-manager.

.DESCRIPTION
Place this in your host repository root and adjust the SubmodulePath
to match your submodule location.

.EXAMPLE
.\manage-dependencies.ps1
.\manage-dependencies.ps1 -Action initial-run
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$PassthroughArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SubmodulePath = Join-Path $ScriptDir "tools\core-pdm-manager"
$MenuScript = Join-Path $SubmodulePath "menu\menu.ps1"

if (Test-Path $MenuScript) {
    & $MenuScript -ProjectRoot $ScriptDir @PassthroughArgs
} else {
    Write-Host "[WARN] core-pdm-manager submodule not found at: $SubmodulePath" -ForegroundColor Yellow
    Write-Host "       Run: git submodule update --init --recursive" -ForegroundColor Yellow
    exit 1
}
