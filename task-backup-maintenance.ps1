. $PSScriptRoot\config.ps1

# this does not really make sense as long as email isn't configured

& $ResticProfileExe repos.check -q > $LogPath\check.log

exit $?
