. $PSScriptRoot\load-env.ps1

executeProfileAndTask -ProfileName daily -Task backup
$BackupExitCode=$LASTEXITCODE

if ((hostname) -eq $MaintenanceHost) {
	executeProfileAndTask -ProfileName repos -Task prune
	$PruneExitCode=$LASTEXITCODE
} else {
	$PruneExitCode=0
}

# Forward exit code to Task Scheduler (TS) from last native program (meaning restic/resticprofile) or last exit-command.
# This has no effect on getting TS to rerun 'failed' tasks, as TS doesn't consider a task failed 
# based on exit code, however it does allow us to see the code in TS.
if ($BackupExitCode -gt 0) {
	exit $BackupExitCode
} else {
	exit $PruneExitCode
}
