# Note this file is not used by resticprofile. Its just usefull to access restic directly

# Template file for backup destination configuration and email passwords.
# Update this file to point to your restic repository and email service.
# Rename to `secrets.ps1`

# restic backup repository configuration
$Env:AWS_ACCESS_KEY_ID='<KEY>'
$Env:AWS_SECRET_ACCESS_KEY='<KEY>'
$Env:RESTIC_REPOSITORY='<REPO URL>'
$Env:RESTIC_PASSWORD='<BACKUP PASSWORD>'

