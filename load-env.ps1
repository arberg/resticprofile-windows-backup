. $PSScriptRoot\config.ps1
. $PSScriptRoot\secrets.ps1 # for restic direct access via shell for user, not needed by scripts

# Gets hostname by running this program, with same case as Restic
$myHost=hostname
