. $PSScriptRoot\config.ps1

$Success=$True

& $ResticProfileExe daily.backup -q > $LogPath\daily.log
$Success = $? -And $Success

& $ResticProfileExe repos.prune -q > $LogPath\daily-prune.log
$Success = $? -And $Success

if (-Not $Success) {exit 1}