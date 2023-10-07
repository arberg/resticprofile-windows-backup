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

scheduleTask `
    -ReplaceCurrentTask `
    -BackupTaskName "Backup\Restic Backup - Maintenance" `
    -Command ".\task-backup-check.ps1" `
    -BackupTaskTrigger (New-ScheduledTaskTrigger -Weekly -At 11:40 -DaysOfWeek 0)

# .\resticprofile.exe  all.schedule