# update.ps1 - called when config changed and this file exists.
#
# DELETE THIS FILE to make every config change replace the resource instead
# (delete-then-create). Its presence alone enables in-place updates.
#
# $InputData holds the PLANNED config attributes plus 'id'. Attributes marked
# requires_replace in resource.tfps.json (path) never reach this script - a change to
# them replaces the resource - so only 'content' changes land here.

Set-Content -LiteralPath $InputData.id -Value $InputData.content -NoNewline

$file = Get-Item -LiteralPath $InputData.id
@{
    id            = $file.FullName
    size          = [int]$file.Length
    last_modified = $file.LastWriteTimeUtc.ToString('o')
}
