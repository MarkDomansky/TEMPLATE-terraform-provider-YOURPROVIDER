# MANAGED FILE - do not edit in your fork.
#
# Script-level unit-test harness: runs ONE CRUD script in-process with a fake
# $InputData, enforcing the engine contract, WITHOUT terraform, Go, or the
# pshost sidecar. Because the script runs in the calling PowerShell session,
# Pester's Mock works on any cmdlet the script calls - so tests are fast and
# never touch the real target system.
#
# Contract enforced (mirrors the engine):
#   - the script sees $InputData (hashtable) and $Action
#   - anything written to the error stream fails the run
#   - create/update must emit exactly one object; read/delete may emit zero
#   - create must emit a non-empty 'id'

$ErrorActionPreference = 'Stop'

# Repo root is three levels up from .template/tests/harness.
$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..')).Path

function Get-ResourceScriptPath {
    # Path of one CRUD script, e.g. provider/resources/<name>/create.ps1.
    param(
        [ValidateSet('resources', 'data-sources')][string]$Kind = 'resources',
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('create', 'read', 'update', 'delete')][string]$Action
    )
    Join-Path $script:RepoRoot 'provider' $Kind $Name "$Action.ps1"
}

function Get-ResourceManifest {
    # Parsed manifest (resource.tfps.json / datasource.tfps.json) of a resource
    # or data source. (Full validation lives in the engine; `go test ./...`
    # runs it against the embedded tree.)
    param(
        [ValidateSet('resources', 'data-sources')][string]$Kind = 'resources',
        [Parameter(Mandatory)][string]$Name
    )
    $manifestName = if ($Kind -eq 'data-sources') { 'datasource.tfps.json' } else { 'resource.tfps.json' }
    $path = Join-Path $script:RepoRoot 'provider' $Kind $Name $manifestName
    if (-not (Test-Path -LiteralPath $path)) { throw "No $manifestName at $path" }
    Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

function Invoke-ResourceScript {
    # Run one CRUD script with a fake $InputData and return the emitted object
    # (a hashtable/PSObject), enforcing the engine contract. Set up globals
    # (e.g. $global:ProviderData, your own state) before calling, or pass
    # -ProviderData to have $global:ProviderData populated for the call.
    param(
        [ValidateSet('resources', 'data-sources')][string]$Kind = 'resources',
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('create', 'read', 'update', 'delete')][string]$Action,
        [hashtable]$InputData = @{},
        # Becomes $global:ProviderData for the duration of the call. Put your
        # custom provider attributes under .Config, mirroring the engine.
        [hashtable]$ProviderData
    )

    $scriptPath = Get-ResourceScriptPath -Kind $Kind -Name $Name -Action $Action
    if (-not (Test-Path -LiteralPath $scriptPath)) { throw "No script at $scriptPath" }
    $content = Get-Content -LiteralPath $scriptPath -Raw

    $prevProviderData = $global:ProviderData
    if ($PSBoundParameters.ContainsKey('ProviderData')) {
        $global:ProviderData = $ProviderData
    }

    try {
        # Mirror the engine: it injects param($InputData) itself, so scripts
        # must not declare their own param block.
        if ($content -match '(?m)^\s*param\s*\(') {
            throw "$scriptPath declares a param(...) block; the engine injects `$InputData itself - remove it."
        }
        $sb = [scriptblock]::Create("param(`$InputData, `$Action)`n$content")

        $errors = @()
        $emitted = @(& $sb $InputData $Action 2>&1 | ForEach-Object {
                if ($_ -is [System.Management.Automation.ErrorRecord]) { $errors += $_ } else { $_ }
            })

        if ($errors.Count -gt 0) {
            throw "Script $Action.ps1 wrote to the error stream (this fails the operation in the engine):`n$($errors -join "`n")"
        }
        if ($emitted.Count -gt 1) {
            throw "Script $Action.ps1 emitted $($emitted.Count) objects; the engine requires exactly one (pipe stray output to Out-Null)."
        }
        if ($emitted.Count -eq 0) {
            if ($Action -in 'create', 'update') {
                throw "Script $Action.ps1 emitted nothing; create/update must emit exactly one object."
            }
            return $null
        }

        $result = $emitted[0]
        if ($Action -eq 'create') {
            $id = if ($result -is [hashtable]) { $result['id'] } else { $result.id }
            if (-not $id) {
                throw "create.ps1 must emit a non-empty 'id' (got: $($result | ConvertTo-Json -Compress -Depth 5))"
            }
        }
        return $result
    }
    finally {
        $global:ProviderData = $prevProviderData
    }
}

Export-ModuleMember -Function Invoke-ResourceScript, Get-ResourceScriptPath, Get-ResourceManifest
