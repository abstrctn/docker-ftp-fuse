#!/bin/bash

mount_point=/mnt/bucket

# Load variables from Secret Manager
project_id=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/project/project-id)
token=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token | jq -j '.access_token')

secret_name=projects/$project_id/secrets/FTP_PASSWORD/versions/latest
ftp_pass=$(curl \
  -H "Authorization: Bearer $token" \
  https://secretmanager.googleapis.com/v1beta1/$secret_name:access \
  | jq -j '.payload.data' | base64 -d)

service vsftpd start

# Create ftp user
# Note, user's home directory needs to exist, even if it's not vsftp's local_root
if id $FTP_USERNAME &>/dev/null; then
  :
else
  adduser $FTP_USERNAME --disabled-password -q --gecos GECOS
  echo "$FTP_USERNAME:$ftp_pass" | /usr/sbin/chpasswd
fi

# Create mount point and change ownership to ftp user
mkdir -p $mount_point
chown $FTP_USERNAME $mount_point
chgrp $FTP_USERNAME $mount_point

echo "user_allow_other" >> /etc/fuse.conf

# Rn gcsfuse as the ftp user
su $FTP_USERNAME -c "gcsfuse --foreground -o allow_other $FTP_BUCKET $mount_point"
