# Edit this to customize the tasks as needed.
# Edit the command-scripts as well if needed

scheduleTask `
    -ReplaceCurrentTask `
    -BackupTaskName "Backup\Restic Backup - Daily" `
    -Command ".\task-backup-daily.ps1"

scheduleTask `
    -ReplaceCurrentTask `
    -BackupTaskName "Backup\Restic Backup - Frequent" `
    -Command ".\task-backup-frequent.ps1" `
    -BackupTaskTrigger (createHourlyTrigger (New-TimeSpan -Minutes 60))

if ((hostname) -eq $MaintenanceHost) {
    scheduleTask `
        -ReplaceCurrentTask `
        -BackupTaskName "Backup\Restic Backup - Maintenance" `
        -Command ".\task-maintenance.ps1" `
        -BackupTaskTrigger (New-ScheduledTaskTrigger -Weekly -At 11:40 -DaysOfWeek 0)    
} else {
    Write-Host "This host ($(hostname)) is no the registered maintance host ($MaintenanceHost), so skipping maintenance-task."
}

# .\resticprofile.exe  all.schedule