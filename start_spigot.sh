#!/usr/bin/env bash

spigot_directory=/opt/spigot
spigot_user=spigot
start_command="/usr/bin/java '-Duser.dir=$spigot_directory' -jar '$spigot_directory/spigot.jar'"

sudo -u "$spigot_user" "$start_command"