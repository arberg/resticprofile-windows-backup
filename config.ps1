# backup configuration
# - InstallPath is this script dir
# - $ResticExe and $ResticProfileExe are the location of the exe-files. 
#   If the don't exists they will be downloaded on ./install.ps1. They can be 
#   externally installed and located elsewhere, but will be updated using self-update
$InstallPath = "C:\Tools\Restic"
$ExeName = "restic.exe"
$ResticExe = Join-Path $InstallPath $ExeName # can be externally installed version, but we will call self-update on it
$ResticProfileExe = Join-Path $InstallPath "resticprofile.exe"
$dirPid = Join-Path $InstallPath "pid"
$WaitPidLockSeconds=(2*3600)

# Create host dirs for each host this script runs on, and link profile to main. This makes it easier to sync backup folder between pc's and keep separate configs
$UseMultiHostsDir = $True

$LogPath = Join-Path $InstallPath "logs"
$LogRetentionDays = 30

# Test what happens on errors
# $LastExitCode is the return code of native applications. $? just returns True or False depending on whether the last command (cmdlet or native) exited without error or not.
# https://stackoverflow.com/questions/10666035/difference-between-and-lastexitcode-in-powershell
$LogFileExitCodes = Join-Path $LogPath "tasks-exit-codes.log" # todo delete cleanup

# Only needed for multi-pc backup towards same repository. Set this to the hostname of the PC which should run the weekly check and prune tasks. Execute 'hostname' command to get your hostname.
$MaintenanceHost = hostname

# Restic Cache-dir. Also set in profiles. This here is only used if restic is executed directly from shell after .\load-env.ps1 
#  - Since we run tasks as system, but user might invoke custom operations as Administrator or user admin user we set it to programdata
#  - If this is updated also consider updating exclusion in windows.exclude file
# 
# If you use Macrium Reflect for image backup, you may also consider adding this directory to the exclusions. See ./registry/MacriumExceptions.reg
#
# Default value for restic is 
#    %LOCALAPPDATA%/restic 
#    pwsh: $env:LOCALAPPDATA\restic
#  which for normail users and administrator is 
#    C:\Users\<user>\AppData\Local\restic
#  and for system user is 
#    c:\Windows\System32\config\systemprofile\AppData\Local\restic 
$Env:RESTIC_CACHE_DIR="c:\ProgramData\restic-cache"
