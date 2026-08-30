# Provider shutdown script (optional - delete this file if you don't need one).
#
# Runs once when the provider tears down, after every resource operation and
# after the practitioner's shutdown_script. Disconnect/clean up here, e.g.:
#
#   Disconnect-ExchangeOnline -Confirm:$false

$global:YourProviderState = $null
