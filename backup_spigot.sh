#!/usr/bin/env bash

spigot_directory=/opt/spigot
spigot_user=spigot
s3_bucket=minecraft.cooley.tech
server_name=minecraft.cooley.tech
backup_name="$spigot_directory/backups/$server_name-backup-$(date -Is).zip"

if
  spigot_pid=$(pgrep -f '^java -jar spigot.*\.jar$')
then
  echo "Stopping Spigot ..."
  kill "$spigot_pid"
fi
cd "$spigot_directory"/.. || exit 1
echo "Creating backup at $backup_name ..."
zip --exclude "$(basename "$spigot_directory")"/backups/\* \
  --exclude "$(basename "$spigot_directory")"/logs/\* \
  -r "$backup_name" "$(basename "$spigot_directory")"
echo "Uploading backup to s3://$s3_bucket/backups/$backup_name"
aws s3 cp "$backup_name" "s3://$s3_bucket/backups/"