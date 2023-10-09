. $PSScriptRoot\load-env.ps1

executeProfileAndTask daily.backup
"[[daily.backup]] $(Get-Date -uformat "%Y-%m-%d %H%M") Exit code: $LASTEXITCODE" >> $LogFileExitCodes
$BackupExitCode=$LASTEXITCODE

executeProfileAndTask repos.prune
"[[repos.prune]] $(Get-Date -uformat "%Y-%m-%d %H%M") Exit code: $LASTEXITCODE" >> $LogFileExitCodes
$PruneExitCode=$LASTEXITCODE

# Forward exit code to Task Scheduler (TS) from last native program (meaning restic/resticprofile) or last exit-command.
# This has no effect on getting TS to rerun 'failed' tasks, as TS doesn't consider a task failed 
# based on exit code, however it does allow us to see the code in TS.
if ($BackupExitCode -gt 0) {
	exit $BackupExitCode
} else {
	exit $PruneExitCode
}
