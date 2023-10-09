. $PSScriptRoot\load-env.ps1

executeProfileAndTask repos.check
"[[repos.check]] $(Get-Date -uformat "%Y-%m-%d %H%M") Exit code: $LASTEXITCODE" >> $LogFileExitCodes

exit $LASTEXITCODE