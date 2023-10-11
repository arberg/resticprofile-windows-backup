. $PSScriptRoot\PidLock.ps1

function cleanupOldResticLogFiles() {
    Get-ChildItem $LogPath | Where-Object {$_.CreationTime -lt $(Get-Date).AddDays(-$LogRetentionDays)} | Remove-Item
}

function deleteFileIfEmpty([string]$Filename) {
	if ((Get-Item -ErrorAction SilentlyContinue $Filename).Length -eq 0) {
		Remove-Item $Filename
	}
}

function getTimestampForLog() {
	return Get-Date -uformat "%Y/%m/%d %H:%M:%S"
}


function waitForRepository([string]$ProfileName, [int]$TimeoutSeconds, $LogFile) {
    $SleepDuration=300 # sleep 5 minutes
    $HasWaited=$False
    $Success=$False
    $stopwatch = [System.Diagnostics.Stopwatch]::new()
    $stopwatch.Start()
    while (-Not $Success){
    	$OutputLines=& $ResticProfileExe -q -n $ProfileName cat config 2>&1
        if ($LASTEXITCODE -ne 0) {
        	$NextSleep=( @( ($TimeoutSeconds-$stopwatch.Elapsed.TotalSeconds), $SleepDuration ) | Measure-Object -Minimum).minimum # Min(remainingTime, sleepDuration)
            if ($NextSleep -le 0) {
            	$OutputLines >> $LogFile
            	$Message="Repository did not become available within timelimit $TimeoutSeconds sec, aborting. Last exitCode: $LASTEXITCODE"
            	"$(getTimestampForLog) $Message" >> $LogFile

                throw $Message
            } else {
                if (-Not $HasWaited) { 
                	"$(getTimestampForLog) Waiting repository to become available, exitCode $LASTEXITCODE" >> $LogFile
	            	$OutputLines >> $LogFile
            	}
                $HasWaited = $True
                sleep $NextSleep
            }
        } else {
            $Success=$True
        }
    }
    if ($HasWaited) { "$(getTimestampForLog) Repository now available" >> $LogFile }
}

function executeProfileAndTask($ProfileName, $Task) {
	$ProfileTask="$ProfileName.$Task"

	$Date = Get-Date -uformat "%Y-%m-%d_%H%M%S" # Get-Date -Format FileDateTime
	# $Date = Get-Date -Format FileDateTime # Use this is you need to run multiple at the same time, such as for testing locks
	$LogFile = Join-Path $LogPath ("$ProfileTask-$Date.log")
	$LogFileErrors = Join-Path $LogPath ("$ProfileTask-$Date.err.log")
	try {
		waitForRepository -ProfileName:$ProfileName -TimeoutSeconds $WaitRepositoryAvailableSeconds $LogFile
		& executeWithPidLock -ScriptSource "Restic" -TimeoutSeconds $WaitPidLockSeconds -LogFile:$LogFile {

			"[[$ProfileTask]] Start $(Get-Date)" >> $LogFile

			# ResticProfile -v2 format version does not write logs to logfile when using --log $LogFile, resticprofile v0.23.0, and even when file exists, created with 'New-Item -Type File $LogFile'. If file does not exists, it gives error

			$Duration = Measure-Command {
					& $ResticProfileExe $ProfileTask 2>> $LogFileErrors 3>&1 >> $LogFile
			}
			deleteFileIfEmpty $LogFileErrors

			cleanupOldResticLogFiles

			"[[$ProfileTask]] End $(Get-Date) - Duration: $Duration" >> $LogFile
		}
	} catch {
		"[[$ProfileTask]] $(Get-Date) Error thrown: " + $_ >> $LogFileErrors
		#$_ >> $LogFileErrors
	}
}
