#!/usr/bin/env bash

spigot_directory=/opt/spigot
spigot_user=spigot
stop_command=(/usr/local/bin/mcrcon -p rcon stop)

cd "$spigot_directory" || exit 1
sudo -u "$spigot_user" "${stop_command[@]}"
