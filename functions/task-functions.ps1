. $PSScriptRoot\PidLock.ps1

function cleanupOldResticLogFiles() {
    Get-ChildItem $LogPath | Where-Object {$_.CreationTime -lt $(Get-Date).AddDays(-$LogRetentionDays)} | Remove-Item
}

function deleteFileIfEmpty([string]$Filename) {
	if ((Get-Item -ErrorAction SilentlyContinue $Filename).Length -eq 0) {
		Remove-Item $Filename
	}
}

function executeProfileAndTask($Name) {
	& executeWithPidLock -ScriptSource "Restic" -TimeoutSeconds $WaitPidLockSeconds {
		$Date = Get-Date -uformat "%Y-%m-%d_%H%M" # Get-Date -Format FileDateTime
		# $Date = Get-Date -Format FileDateTime # Use this is you need to run multiple at the same time, such as for testing locks
		$LogFile = Join-Path $LogPath ("$Name-$Date.log")
		$LogFileErrors = Join-Path $LogPath ("$Name-$Date.err.log")

		"[[$Name]] Start $(Get-Date)" >> $LogFile

		# ResticProfile -v2 format version does not write logs to logfile when using --log $LogFile, resticprofile v0.23.0, and even when file exists, created with 'New-Item -Type File $LogFile'. If file does not exists, it gives error

		$Duration = Measure-Command {
				& $ResticProfileExe $Name 2>> $LogFileErrors 3>&1 >> $LogFile
		}
		deleteFileIfEmpty $LogFileErrors

		cleanupOldResticLogFiles

		"[[$Name]] End $(Get-Date) - Duration: $Duration" >> $LogFile
	}

}
