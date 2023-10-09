# Usage: pidFile($MyInvocation.MyCommand.Source)
function pidFile([string]$ScriptSource) {
    $ScriptName=Split-Path $ScriptSource -Leaf
    # $dirPid is defined in common-setup
    if ($dirPid -And -Not (Test-Path $dirPid)) { 
        New-Item -Type Directory $dirPid 
    }
    return ($dirPid ? "$dirPid\" : "") + "$ScriptName.pid"
}    

function lastExecutedTimestampFile([string]$ScriptSource) {
    if (-Not $ScriptSource) { throw "lastExecutedTimestampFile: Missing -ScriptSource"}
    $ScriptName=Split-Path $ScriptSource -Leaf
    # $dirPid is defined in common-setup
    return ($dirLastExecuted ? "$dirLastExecuted\" : "") + "$ScriptName.last"
}

# Usage: executeWithPidLock($MyInvocation.MyCommand.Source) { }
### Warning: executeWithPidLock causes crappy exceptions because if below throws then it lists the pidLock as cause, so outcomment while developing it
### - Plus it messes with printout from robocopy and yt-dlp
function executeWithPidLock([string]$ScriptSource, [int]$TimeoutSeconds=0, [ScriptBlock]$Block) {
    $PID_FILE=takePidLock $ScriptSource -TimeoutSeconds:$TimeoutSeconds
    try {
        $Block.Invoke() | Out-Host
    } finally {
        # robocopy moves my pid-file if placed in temp download dir. 
        rm $PID_FILE
    }
}

# Usage: takePidLock($MyInvocation.MyCommand.Source)
function takePidLock([string]$ScriptSource, [int]$TimeoutSeconds=0) {
    # How to prevent dual execution? see also
    # https://stackoverflow.com/questions/15969662/assure-only-1-instance-of-powershell-script-is-running-at-any-given-time
    $PID_FILE=pidFile -ScriptSource $ScriptSource
    # Write-Host -ForegroundColor Magenta "My PID $PID, PidFile: $PID_FILE"
    
    $HasWaitedForPidLock=$False
    $Success=$False
    $stopwatch = [System.Diagnostics.Stopwatch]::new()
    $stopwatch.Start()
    
    while (-Not $Success){
        if (Test-Path $PID_FILE) {
            $OTHER_PID=Get-Content $PID_FILE
            if ((Get-Process -id $OTHER_PID -ErrorAction SilentlyContinue) -And ($PID -ne $OTHER_PID)) {
                if ($TimeoutSeconds -gt 0) {
                    if ($stopwatch.Elapsed.TotalSeconds -gt $TimeoutSeconds) {
                        throw "Unable to get PID lock within timelimit, aborting." 
                    } else {
                        if (-Not $HasWaitedForPidLock) { Write-Host "Waiting for PID-Lock from process $OTHER_PID" }
                        $HasWaitedForPidLock = $True
                        # Only wait 1 second at a time, since will wait for the PID of the surrounding powershell process, which could be longer than the task
                        Wait-Process -Id $OTHER_PID -Timeout 1 -ErrorAction SilentlyContinue
                        # Other process has either stopped or timeout has passed
                    }
                } else {
                    throw "Already running with Powershell PID $OTHER_PID. See $PID_FILE"
                }
            } else {
                $Success=$True
                Write-Host -ForegroundColor Yellow "Found old pid-file but process gone. Allowing this to run"
            }
        } else {
            $Success=$True
        }
    }
    $PID | Out-File $PID_FILE
    if (-Not (Test-Path $PID_FILE)) {
        throw "PID_FILE should exist now: $PID_FILE"
    }
    $CurrentPidFileContent=Get-Content $PID_FILE
    if ($CurrentPidFileContent -ne $PID) {
        throw "PID_FILE written, but not written by us, as PID is wrong: myPid: $PID, PID_FILE content: $CurrentPidFileContent"
    }

    if ($HasWaitedForPidLock) {
        Write-Host "Executing $ScriptSource, acquired PID lock..."
    }
    # Write-Host -ForegroundColor Magenta "Taken PidFile: $PID_FILE"
    return $PID_FILE
}

# Usage: try {} finally { releasePidLock($MyInvocation.MyCommand.Source) }
function releasePidLock([string]$ScriptSource) {
    $PID_FILE=pidFile -ScriptSource $ScriptSource
    rm $PID_FILE
}


# Usage: takePidLock($MyInvocation.MyCommand.Source)
function Get-LastExecutedTimestamp([string]$ScriptSource, [switch]$Verbose=$false) {
    if (-Not $ScriptSource) { throw "Get-LastExecutedTimestamp: Missing -ScriptSource"}

    # How to prevent dual execution? see also
    # https://stackoverflow.com/questions/15969662/assure-only-1-instance-of-powershell-script-is-running-at-any-given-time
    $LAST_EXECUTED_FILE=lastExecutedTimestampFile -ScriptSource $ScriptSource
    if ($Verbose) { Write-Host -ForegroundColor Magenta "LAST EXECUTED FILE" $LAST_EXECUTED_FILE }

    $LastTimestamp=0
    if (Test-Path $LAST_EXECUTED_FILE) {
        $LastTimestampString=(Get-Content $LAST_EXECUTED_FILE)
        $LastTimestamp=Convert-ToNumber $LastTimestampString -DefaultValue 0
    } else {
        $LastTimestamp=0
    }
    return $LastTimestamp
}

function Write-LastExecutedTimestamp([string]$ScriptSource) {
    if (-Not $ScriptSource) { throw "Write-LastExecutedTimestamp: Missing -ScriptSource"}
    $timestamp=Get-TimeSinceTheEpoch

    # How to prevent dual execution? see also
    # https://stackoverflow.com/questions/15969662/assure-only-1-instance-of-powershell-script-is-running-at-any-given-time
    $LAST_EXECUTED_FILE=lastExecutedTimestampFile -ScriptSource $ScriptSource
    echo $timestamp | Out-File $LAST_EXECUTED_FILE
    if (-Not $?) {
        throw "Failed to write timestamp to file, timestamp was $timestamp"
    }

    if ((Get-LastExecutedTimestamp $ScriptSource) -ne $timestamp) {
        throw "Unable to write timestamp to file reliably, after writing file it contained wrong content, expected timestamp $timestamp"
    }

    return $timestamp
}

function Test-ExecuteLastExecutionOlder([int]$RequiredTimePassedSec, [string]$ScriptSource) {
    if (-Not $ScriptSource) { throw "Test-ExecuteLastExecutionOlder: Missing -ScriptSource"}
    $lastExecuted=Get-LastExecutedTimestamp $ScriptSource
    $currentTime=Get-TimeSinceTheEpoch
    if ($lastExecuted + $RequiredTimePassedSec*1000 -lt $currentTime) {
        return $true
    } else {
        return $false
    }
}

# Usage: executeFreqLimited($MyInvocation.MyCommand.Source) { }
# This also takes a pid-lock using the same script-source name
function executeFreqLimited([int]$RequiredTimePassedSec, [switch]$Verbose=$true, [string]$ScriptSource, [ScriptBlock]$Block) {
    if (-Not $RequiredTimePassedSec) { throw "executeFreqLimited: Missing -RequiredTimePassedSec"}
    if (-Not $ScriptSource) { throw "executeFreqLimited: Missing -ScriptSource"}
    # Execute with pid-lock to avoid multiple running due to starting at the same time. Also we don't write 

    $freqLimitedBlock=$Block # outside below, which changes $Block ref
    executeWithPidLock $ScriptSource {
        $lastExecutedTimestampString=Convert-EpochMsToDateString (Get-LastExecutedTimestamp $ScriptSource)
        $lastExecutedInfo="(last executed: $lastExecutedTimestampString, minInterval: $($RequiredTimePassedSec/3600) h)"
        if (Test-ExecuteLastExecutionOlder $RequiredTimePassedSec $ScriptSource) {
            if ($Verbose) { Write-Host "Executing $lastExecutedInfo" }
            try {
                $freqLimitedBlock.Invoke() | Out-Host
            } finally {
                Write-LastExecutedTimestamp $ScriptSource
            }
        } elseif ($Verbose) {
            Write-Host "Skipping execution due to time not passed yet $lastExecutedInfo"
        }
    }
}
