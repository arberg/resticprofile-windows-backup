. $PSScriptRoot\load-env.ps1

# download restic
if(-not (Test-Path $ResticExe)) {
    $url = $null
    if([Environment]::Is64BitOperatingSystem){
        $url = "https://github.com/restic/restic/releases/download/v0.15.0/restic_0.15.0_windows_amd64.zip"
    }
    else {
        $url = "https://github.com/restic/restic/releases/download/v0.15.0/restic_0.15.0_windows_386.zip"
    }
    $output = Join-Path $InstallPath "restic.zip"
    Invoke-WebRequest -Uri $url -OutFile $output
    Expand-Archive -LiteralPath $output $InstallPath
    Remove-Item $output
    Get-ChildItem *.exe | Rename-Item -NewName $ExeName
    Write-Host -ForegroundColor Magenta "[[Install]] Downloaded restic"
}

if(-not (Test-Path $ResticProfileExe)) {
    Write-Host 
    $url = $null
    $version="0.23.0"
    if ([Environment]::Is64BitOperatingSystem) {
        $filename = "resticprofile_${version}_windows_amd64.zip"
    } else {
        $filename = "resticprofile_${version}_windows_386.zip"
        $url = "https://github.com/creativeprojects/resticprofile/releases/download/v${version}/"
    }
    $url = "https://github.com/creativeprojects/resticprofile/releases/download/v${version}/$filename"
    $output = Join-Path $InstallPath $filename
    $TempDir="temp-resticprofile"
    mkdir $TempDir > $null
    Invoke-WebRequest -Uri $url -OutFile $output
    Expand-Archive -LiteralPath $output $TempDir
    #Move-Item $TempDir\resticprofile.exe $InstallPath
    Move-Item $TempDir\resticprofile.exe $ResticProfileExe
    Remove-Item $output
    Remove-Item -Recurse $TempDir
    #Get-ChildItem *.exe | Rename-Item -NewName $ResticProfileExe
    Write-Host -ForegroundColor Magenta "[[Install]] Downloaded resticprofile"
}

# Invoke restic self-update to check for a newer version
Write-Host -ForegroundColor Magenta "[[restic]]"
& $ResticExe self-update

# Invoke resticprofile self-update to check for a newer version
Write-Host -ForegroundColor Magenta "[[resticprofile]]"
& $ResticProfileExe self-update

# Create log directory if it doesn't exit
if(-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Force -Path $LogPath | Out-Null
    Write-Host -ForegroundColor Magenta "[[LogPath]] LogPath successfully created: $LogPath"
}

# Initialize the primary repository. Others will have to be initialized manually
& $ResticExe cat config *> $null
if ($?){
    Write-Host -ForegroundColor Magenta "[[Init]] Repository already initialized."
} else {
    # Initialize the restic repository
    & $ResticExe --verbose init
    if($?) {
        Write-Host -ForegroundColor Magenta "[[Init]] Repository successfully initialized."        
    }
    else {
        Write-Warning "[[Init]] Repository initialization failed. Check errors and resolve."
    }
}

if (-Not (Test-Path $dirPid)) { 
    New-Item -Type Directory $dirPid 
}

function Test-IsLink([string]$path) {
    # Alternative (I'm not sure its same semantics, though it is same bevaiour with link created in New-Link below) ((Get-item $path).LinkType -eq "SymbolicLink")
    $file = Get-Item $path -Force -ea SilentlyContinue
    [bool]($file.Attributes -band [IO.FileAttributes]::ReparsePoint)
}

if (Test-isAdministratorRole -And $UseMultiHostsDir) {
    # Create log directory if it doesn't exit
    $HostProfilesDir="$InstallPath\hosts"
    if(-not (Test-Path $HostProfilesDir)) {
        New-Item -ItemType Directory -Force -Path $HostProfilesDir | Out-Null
        Write-Host -ForegroundColor Magenta "[[HostsPath]] HostsPath for profiles successfully created: $HostProfilesDir"
    }
    $CurrentHostDir="$HostProfilesDir\$myHost"
    if(-not (Test-Path $HostProfilesDir)) {
        New-Item -ItemType Directory -Force -Path $HostProfilesDir | Out-Null
        Write-Host -ForegroundColor Magenta "[[HostsPath]] HostsPath for profiles successfully created: $HostProfilesDir"
    }
    if (-Not (Test-Path $CurrentHostDir)) {
        New-Item -ItemType Directory -Force -Path $CurrentHostDir | Out-Null    
    }

    $CurrentHostProfile="$CurrentHostDir\profiles.yaml"
    $profileFile="$InstallPath\profiles.yaml"
    if (-Not (Test-IsLink $profileFile) -And -Not (Test-Path $CurrentHostProfile)) {
        Write-Host -ForegroundColor Magenta "[[HostsPath]] Moving ./profile.yaml to $CurrentHostProfile"
        mv $profileFile $CurrentHostProfile
    }
    
    if (-Not (Test-Path $profileFile)) {
        # Admin right is required for this
        if (-Not (Test-Path $CurrentHostProfile)) {
            New-Item -ItemType File -Force -Path $CurrentHostProfile | Out-Null
        }
        New-Item $profileFile -ItemType SymbolicLink -Value $CurrentHostProfile | Out-Null
        Write-Host -ForegroundColor Magenta "[[HostsPath]] Linked ./profile.yaml to $CurrentHostProfile"
    }
} else {
     Write-Warning "[[HostsPath]] Unable to create link-dirs, as no administrator rights. This is only useful if script-folder is reused on several machines"
}


function scheduleTask([string]$BackupTaskName, [string]$Command=".\backup.ps1", $BackupTaskTrigger, [switch]$ReplaceCurrentTask) {
    # Scheduled Windows Task Scheduler to run the backup
    # TaskPath must be named with leading and ending backslash, as seen in output of 'Get-ScheduledTask', its not required to include it: -TaskPath "$(Split-Path $BackupTaskName -Parent)/" 
    $TaskName=Split-Path $BackupTaskName -Leaf
    $TaskPath=Split-Path $BackupTaskName -Parent
    # Write-host "`$BackupTaskName='$BackupTaskName'"
    # Write-host "`$TaskName='$TaskName'"
    # Write-host "`$TaskPath='$TaskPath'"
    if ($TaskPath -And -Not $TaskPath.startsWith("\")) {
        $TaskPath="\$TaskPath"
    }
    $BackupTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($ReplaceCurrentTask -And $BackupTask) {
        if ($BackupTask.TaskPath -eq "$TaskPath\") {
            Write-Host -ForegroundColor Magenta "[[Scheduler]] Unregistring task by Path '$($BackupTask.TaskPath)' and name '$TaskName'"
            Unregister-ScheduledTask -TaskPath $BackupTask.TaskPath -TaskName $TaskName -Confirm:$false
            $BackupTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue                
        } else {
            Write-Warning "[[Scheduler]] Different task with same name found, this is not necessarily a problem, task path $TaskPath != $($BackupTask.TaskPath)"
        }
    }
    if(($null -eq $BackupTask) -Or $ReplaceCurrentTask) {
        try {
            $task_action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -NonInteractive -NoLogo -NoProfile -Command `"$Command; exit `$LASTEXITCODE`"" -WorkingDirectory $InstallPath
            $task_user = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel Highest
            $task_settings = New-ScheduledTaskSettingsSet -RestartCount 4 -RestartInterval (New-TimeSpan -Minutes 15) -ExecutionTimeLimit (New-TimeSpan -Days 3) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -DontStopOnIdleEnd -MultipleInstances IgnoreNew -IdleDuration 0 -IdleWaitTimeout 0 -StartWhenAvailable -RestartOnIdle
            if ($BackupTaskTrigger) {
                $task_trigger = $BackupTaskTrigger # From config
            } else {
                $task_trigger = New-ScheduledTaskTrigger -Daily -At 4:00am
            }
            Register-ScheduledTask $BackupTaskName -Action $task_action -Principal $task_user -Settings $task_settings -Trigger $task_trigger | Out-Null
            Write-Host -ForegroundColor Magenta "[[Scheduler]] Backup task scheduled."
        }
        catch {
            Write-Warning "[[Scheduler]] Scheduling failed."
        }
    }
    else {
        Write-Warning "[[Scheduler]] Backup task not scheduled: there is already a task with the name '$BackupTaskName'."
    }
}

# (New-TimeSpan -Minutes 15)
function createHourlyTrigger([System.TimeSpan]$TimeSpan) {
    # $BackupTaskTrigger = New-ScheduledTaskTrigger -Daily -At 4:00am # -Daily -At 4:00am - default if this line is not included
    # https://stackoverflow.com/a/54674840
    #  Create secondary trigger (optionally     omit -RepetitionDuration for an indefinite duration; be sure to use the same -At argument):
    $TempTrigger = New-ScheduledTaskTrigger -Once -At 04:00 `
            -RepetitionInterval $TimeSpan `
            -RepetitionDuration (New-TimeSpan -Hours 23 -Minutes 55)

    # Take repetition object from secondary, and insert it into base trigger:
    $BackupTaskTrigger = New-ScheduledTaskTrigger -Daily -At 4:00 # -Daily does not support -RepetitionDuration+Interval, hence the hack with $TempTrigger
    $BackupTaskTrigger.Repetition = $TempTrigger.Repetition

    return $BackupTaskTrigger
}

. $PSScriptRoot/config-install-task.ps1
