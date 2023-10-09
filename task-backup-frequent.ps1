. $PSScriptRoot\load-env.ps1

executeProfileAndTask frequent.backup
"[[frequent.backup]] $(Get-Date -uformat "%Y-%m-%d %H%M") Exit code: $LASTEXITCODE" >> $LogFileExitCodes

exit $LASTEXITCODE