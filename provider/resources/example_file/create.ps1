# create.ps1 - called on `terraform apply` for a new resource.
#
# Contract (applies to every CRUD script):
#   - $InputData is a hashtable holding every non-null config attribute from
#     resource.tfps.json (typed: strings, numbers, bools, arrays, hashtables).
#   - Emit EXACTLY ONE object to the success stream. Pipe stray cmdlet output
#     to Out-Null. Anything on the error stream fails the operation.
#   - create.ps1 must emit an 'id' key: a non-empty string that uniquely
#     identifies the object. Terraform uses it for read/update/delete/import.
#   - Keys matching computed attributes (size, last_modified) populate state;
#     keys matching config attributes are ignored; unknown keys are ignored
#     with a warning in TF_LOG output.

$path = $InputData.path
if (-not [System.IO.Path]::IsPathRooted($path) -and $global:YourProviderState.default_directory) {
    $path = Join-Path $global:YourProviderState.default_directory $path
}

$dir = Split-Path -Parent $path
if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

Set-Content -LiteralPath $path -Value $InputData.content -NoNewline

$file = Get-Item -LiteralPath $path
@{
    id            = $file.FullName
    size          = [int]$file.Length
    last_modified = $file.LastWriteTimeUtc.ToString('o')
}
