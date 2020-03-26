#!/usr/bin/env bash
set -e

usage="Usage: $0 [FUNCTION_NAME]

Available functions:
  accept_eula
  add_spigot_user
  build_spigot
  check_for_root
  download_buildtools
  download_essentials
  install_dependencies
  install_service
"
buildtools_jar_url=https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar
spigot_directory=/opt/spigot
spigot_user=spigot
s3_bucket=minecraft.cooley.tech
spigot_service="[Unit]
Description=spigot

[Service]
ExecStart=/usr/bin/java -jar spigot.jar --noconsole --nogui
ExecStop=/usr/local/bin/mcrcon -p rcon stop
User=$spigot_user
Group=$spigot_user
WorkingDirectory=$spigot_directory
Restart=always
TimeoutStartSec=90
RestartSec=30

[Install]
WantedBy=multi-user.target
"

check_for_root(){
  echo 'Checking for root ...'
  if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
  fi
}

install_dependencies(){
  echo 'Installing dependencies ...'
  yum install -y git java-1.8.0-openjdk-devel jq wget 
  mcrcon_url=$(curl -s https://api.github.com/repos/Tiiffi/mcrcon/releases/latest \
    | jq .assets[].browser_download_url -r \
    | grep linux-x86-64
  )
  wget "$mcrcon_url" --directory-prefix=/tmp
  tar --directory=/tmp/ \
    --strip-components 1 \
    -xzvf /tmp/"$(basename "$mcrcon_url")"
  mv /tmp/mcrcon /usr/local/bin/
}

add_spigot_user(){
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
  ln --symbolic --force "$spigot_jar" "$spigot_directory"/spigot.jar
}

download_essentials()(
  echo 'Downloading plugins and scripts ...'
  aws s3 cp --recursive "s3://$s3_bucket" "$spigot_directory"
  chmod +x "$spigot_directory"/*.sh
  chown -R "$spigot_user:$spigot_user" "$spigot_directory"
)

accept_eula(){
  echo 'Accepting EULA ...'
  echo eula=true > "$spigot_directory"/eula.txt
  chown "$spigot_user:$spigot_user" "$spigot_directory"/eula.txt
}

install_service()(
  echo 'Creating service file ...'
  echo "$spigot_service" > /etc/systemd/system/spigot.service
  echo 'Enabling service ...'
  systemctl enable spigot
  echo 'Starting service ...'
  systemctl start spigot
)

main(){
  check_for_root
  install_dependencies
  download_buildtools
  build_spigot
  add_spigot_user
  download_essentials
  accept_eula
  install_service
}

case $1 in
  accept_eula) "$1" ;;
  add_spigot_user) "$1" ;;
  build_spigot) "$1" ;;
  check_for_root) "$1" ;;
  download_buildtools) "$1" ;;
  download_essentials) "$1" ;;
  install_dependencies) "$1" ;;
  install_service) "$1" ;;
  '' | main) main ;;
  -h | --help | usage | *) echo "$usage" ;; 
esac