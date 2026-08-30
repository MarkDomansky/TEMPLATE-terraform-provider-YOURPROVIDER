# read.ps1 - the only script a data source has.
#
# $InputData holds the config attributes. Emit one object whose keys populate
# the computed attributes; omitted keys become null. Unlike a resource read,
# emitting nothing is not "gone" - it just leaves every computed attribute
# null - so emit an explicit marker like 'exists' when absence matters.

$path = $InputData.path
if (-not [System.IO.Path]::IsPathRooted($path) -and $global:YourProviderState.default_directory) {
    $path = Join-Path $global:YourProviderState.default_directory $path
}

if (-not (Test-Path -LiteralPath $path)) {
    @{ exists = $false }
    return
}

$file = Get-Item -LiteralPath $path
@{
    exists  = $true
    content = (Get-Content -LiteralPath $path -Raw)
    size    = [int]$file.Length
}
