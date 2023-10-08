# backup configuration
# - InstallPath is this script dir
# - $ResticExe and $ResticProfileExe are the location of the exe-files. 
#   If the don't exists they will be downloaded on ./install.ps1. They can be 
#   externally installed and located elsewhere, but will be updated using self-update

$InstallPath = "C:\Tools\Restic"
$ResticExe = Join-Path $InstallPath "restic.exe" # can be externally installed version, but we will call self-update on it
$ResticProfileExe = Join-Path $InstallPath "resticprofile.exe"

# Create host dirs for each host this script runs on, and link profile to main. This makes it easier to sync backup folder between pc's and keep separate configs
$UseMultiHostsDir=$True

$LogPath = Join-Path $InstallPath "logs"
$LogRetentionDays = 30 # TODO

# Only needed for multi-pc backup towards same repository. Set this to the hostname of the PC which should run the weekly check and prune tasks. Execute 'hostname' command to get your hostname.
$MaintenanceHost = hostname