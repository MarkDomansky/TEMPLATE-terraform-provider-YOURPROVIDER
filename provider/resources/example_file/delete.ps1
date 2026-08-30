# delete.ps1 - called on `terraform destroy` (and for the delete half of a
# replacement). $InputData holds the config attributes from state plus 'id'.
# Deleting an already-missing object should succeed (idempotent destroy).

if (Test-Path -LiteralPath $InputData.id) {
    Remove-Item -LiteralPath $InputData.id -Force
}

@{ id = $InputData.id }
