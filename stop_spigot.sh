#!/usr/bin/env bash

spigot_user=spigot
stop_command="/usr/local/bin/mcrcon -p rcon stop"

sudo -u "$spigot_user" "$stop_command"