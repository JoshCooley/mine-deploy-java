#!/usr/bin/env bash

spigot_directory=/opt/spigot
spigot_user=spigot
start_command=(
  nohup
    /usr/bin/java 
      "-Duser.dir=$spigot_directory" 
      -jar "$spigot_directory/spigot.jar"
      --noconsole --nogui
)

cd "$spigot_directory" || exit 1
if [[ $(whoami) == "$spigot_user" ]]; then
  "${start_command[@]}" &> /dev/null &
else
  sudo -u "$spigot_user" "${start_command[@]}" &> /dev/null &
fi

