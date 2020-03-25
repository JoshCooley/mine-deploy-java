#!/usr/bin/env bash
set -e

usage="Usage: $0 [FUNCTION_NAME]"
buildtools_jar_url=https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar
spigot_directory=/opt/spigot
spigot_user=spigot
s3_bucket=minecraft.cooley.tech
monit_version=5.26.0
monit_url=https://mmonit.com/monit/dist/binary/$monit_version/monit-$monit_version-linux-x64.tar.gz
main_monit_config='set log /var/log/monit.log

set httpd unixsocket /var/run/monit.sock
  allow localhost

include /usr/local/etc/monit.d/*
'
spigot_monit_config='check process minecraft
  matching "^java -jar spigot.*jar$"
  start program = "/usr/bin/java -Duser.dir='"'$spigot_directory'"' -jar /opt/spigot/spigot.jar" as uid "'$spigot_user'" and gid "'$spigot_user'"
  stop program = "/usr/local/bin/mcrcon -p rcon stop"
  if failed port 25565 with timeout 30 seconds then restart
  if failed port 8123  with timeout 120 seconds then restart
'
mcrcon_url=$(curl -s https://api.github.com/repos/Tiiffi/mcrcon/releases/latest \
  | jq .assets[].browser_download_url -r \
  | grep linux-x86-64
)

check_for_root(){
  echo 'Checking for root ...'
  if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
  fi
}

install_dependencies(){
  echo 'Installing dependencies ...'
  yum install -y git java-1.8.0-openjdk-devel wget
  wget "$mcrcon_url" --directory-prefix=/tmp
  tar --directory=/tmp/ \
    --strip-components 1 \
    -xzvf /tmp/"$(basename "$mcrcon_url")"
  mv /tmp/mcrcon /usr/local/bin/
}

add_spigot_user_and_change_ownership(){
  useradd --system \
    --home-dir "$spigot_directory" \
    "$spigot_user"
  chown -R "$spigot_user:$spigot_user" "$spigot_directory"
}

download_buildtools(){
  echo 'Downloading buildtools ...' -O 
  wget "$buildtools_jar_url" --directory-prefix="$spigot_directory"
}

build_spigot(){
  export HOME=$spigot_directory
  echo 'Building Spigot ...'
  java -jar "$spigot_directory"/BuildTools.jar --output-dir "$spigot_directory"
  spigot_jar=$(tail -1 BuildTools.log.txt | cut -d ' ' -f 6)
  ln -s "$spigot_jar" "$spigot_directory"/spigot.jar
}

download_plugins()(
  echo 'Downloading plugins ...'
  mkdir "$spigot_directory"/plugins
  aws s3 cp --recursive "s3://$s3_bucket/plugins" "$spigot_directory"/plugins
)

accept_eula(){
  echo 'Accepting EULA ...'
  echo eula=true > "$spigot_directory"/eula.txt
}

install_monit()(
  echo 'Downloading Monit ...'
  mkdir /tmp/monit
  wget --directory-prefix=/tmp/monit "$monit_url"
  tar --directory=/tmp/monit \
    -xzvf /tmp/monit/monit-$monit_version-linux-x64.tar.gz
  echo 'Installing Monit ...'
  cp "/tmp/monit/monit-$monit_version/bin/monit" /usr/local/bin/
  gzip --stdout "/tmp/monit/monit-$monit_version/man/man1/monit.1" \
    > /usr/local/share/man/man1/monit.1.gz
  mkdir /usr/local/etc/monit.d
  echo "$main_monit_config" > /usr/local/etc/monitrc
  chmod 600 /usr/local/etc/monitrc
  echo "$spigot_monit_config" > /usr/local/etc/monit.d/spigot
)

main(){
  check_for_root
  install_dependencies
  download_buildtools
  build_spigot
  download_plugins
  accept_eula
  add_spigot_user_and_change_ownership
  install_monit
}

case $1 in
  accept_eula) "$1" ;;
  add_spigot_user) "$1" ;;
  add_spigot_user_and_change_ownership) "$1" ;;
  build_spigot) "$1" ;;
  check_for_root) "$1" ;;
  download_buildtools) "$1" ;;
  download_plugins) "$1" ;;
  install_dependencies) "$1" ;;
  install_monit) "$1" ;;
  '' | main) main ;;
  -h | --help | usage | *) echo "$usage" ;; 
esac