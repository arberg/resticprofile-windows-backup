. $PSScriptRoot\load-env.ps1

executeProfileAndTask -ProfileName repos -Task check

exit $LASTEXITCODE