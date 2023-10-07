. $PSScriptRoot\load-env.ps1

& $ResticExe snapshots --host $myHost @args
