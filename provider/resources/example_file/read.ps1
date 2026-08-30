# read.ps1 - called on `terraform plan`/`refresh` and after import.
#
# $InputData holds the config attributes from state PLUS 'id' (what create
# emitted). Emitting NOTHING tells Terraform the object no longer exists, so
# it plans recreation. Only computed attributes are refreshed from the emitted
# object; config attributes always come from state.

if (-not (Test-Path -LiteralPath $InputData.id)) {
    return
}

$file = Get-Item -LiteralPath $InputData.id
@{
    id            = $file.FullName
    size          = [int]$file.Length
    last_modified = $file.LastWriteTimeUtc.ToString('o')
}
