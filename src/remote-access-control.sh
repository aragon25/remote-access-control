#!/bin/bash
##############################################
##                                          ##
##  remote-access-control                   ##
##                                          ##
##############################################

#get some variables
SCRIPT_TITLE="remote-access-control"
SCRIPT_VERSION="1.3"
SCRIPTDIR="$(readlink -f "$0")"
SCRIPTNAME="$(basename "$SCRIPTDIR")"
SCRIPTDIR="$(dirname "$SCRIPTDIR")"

#!!!RUN RESTRICTIONS!!!
#only for raspberry pi (rpi5|rpi4|rpi3|all) can combined!
raspi="all"
#only for Raspbian OS (bookworm|bullseye|all) can combined!
rasos="bookworm|bullseye"
#only for cpu architecture (i386|armhf|amd64|arm64) can combined!
cpuarch=""
#only for os architecture (32|64) can NOT combined!
bsarch=""
#this aptpaks need to be installed!
aptpaks=( dhcpcd5 network-manager )

#check commands
case $1 in
  --disable_cockpit)
  CMD="disable_cockpit"
  shift # past argument
  ;;
  --enable_cockpit)
  CMD="enable_cockpit"
  shift # past argument
  ;;
  --disable_vnc)
  CMD="disable_vnc"
  shift # past argument
  ;;
  --enable_vnc)
  CMD="enable_vnc"
  shift # past argument
  ;;
  --disable_vnc-web)
  CMD="disable_vnc-web"
  shift # past argument
  ;;
  --enable_vnc-web)
  CMD="enable_vnc-web"
  shift # past argument
  ;;
  --disable_ssh)
  CMD="disable_ssh"
  shift # past argument
  ;;
  --enable_ssh)
  CMD="enable_ssh"
  shift # past argument
  ;;
  --disable_wlan_pwrsave)
  CMD="disable_wlan_pwrsave"
  shift # past argument
  ;;
  --enable_wlan_pwrsave)
  CMD="enable_wlan_pwrsave"
  shift # past argument
  ;;
  --use_networkmanager)
  CMD="use_networkmanager"
  shift # past argument
  ;;
  --use_dhcpcd)
  CMD="use_dhcpcd"
  shift # past argument
  ;;
  -v|--version)
  CMD="version"
  shift # past argument
  ;;
  -h|--help)
  CMD="help"
  shift # past argument
  ;;
  *)
  if [ "$1" != "" ]
  then
    echo "Unknown option: $1"
    exit 1
  fi
  ;;
esac
if [ "$2" != "" ] 
then
  echo "Only one option at same time is allowed!"
  exit 1
fi
[ "$CMD" == "" ] && CMD="help"

function do_check_start() {
  #check if superuser
  if [ $UID -ne 0 ]; then
    echo "Please run this script with Superuser privileges!"
    exit 1
  fi
  #check if raspberry pi 
  if [ "$raspi" != "" ]; then
    raspi_v="$(tr -d '\0' 2>/dev/null < /proc/device-tree/model)"
    local raspi_res="false"
    [[ "$raspi_v" =~ "Raspberry Pi" ]] && [[ "$raspi" =~ "all" ]] && raspi_res="true"
    [[ "$raspi_v" =~ "Raspberry Pi 3" ]] && [[ "$raspi" =~ "rpi3" ]] && raspi_res="true"
    [[ "$raspi_v" =~ "Raspberry Pi 4" ]] && [[ "$raspi" =~ "rpi4" ]] && raspi_res="true"
    [[ "$raspi_v" =~ "Raspberry Pi 5" ]] && [[ "$raspi" =~ "rpi5" ]] && raspi_res="true"
    if [ "$raspi_res" == "false" ]; then
      echo "This Device seems not to be an Raspberry Pi ($raspi)! Can not continue with this script!"
      exit 1
    fi
  fi
  #check if raspbian
  if [ "$rasos" != "" ]
  then
    rasos_v="$(lsb_release -d -s 2>/dev/null)"
    [ -f /etc/rpi-issue ] && rasos_v="Raspbian ${rasos_v}"
    local rasos_res="false"
    [[ "$rasos_v" =~ "Raspbian" ]] && [[ "$rasos" =~ "all" ]] && rasos_res="true"
    [[ "$rasos_v" =~ "Raspbian" ]] && [[ "$rasos_v" =~ "bullseye" ]] && [[ "$rasos" =~ "bullseye" ]] && rasos_res="true"
    [[ "$rasos_v" =~ "Raspbian" ]] && [[ "$rasos_v" =~ "bookworm" ]] && [[ "$rasos" =~ "bookworm" ]] && rasos_res="true"
    if [ "$rasos_res" == "false" ]; then
      echo "You need to run Raspbian OS ($rasos) to run this script! Can not continue with this script!"
      exit 1
    fi
  fi
  #check cpu architecture
  if [ "$cpuarch" != "" ]; then
    cpuarch_v="$(dpkg --print-architecture 2>/dev/null)"
    if [[ ! "$cpuarch" =~ "$cpuarch_v" ]]; then
      echo "Your CPU Architecture ($cpuarch_v) is not supported! Can not continue with this script!"
      exit 1
    fi
  fi
  #check os architecture
  if [ "$bsarch" == "32" ] || [ "$bsarch" == "64" ]; then
    bsarch_v="$(getconf LONG_BIT 2>/dev/null)"
    if [ "$bsarch" != "$bsarch_v" ]; then
      echo "Your OS Architecture ($bsarch_v) is not supported! Can not continue with this script!"
      exit 1
    fi
  fi
  #check apt paks
  local apt
  local apt_res
  IFS=$' '
  if [ "${#aptpaks[@]}" != "0" ]; then
    for apt in ${aptpaks[@]}; do
      [[ ! "$(dpkg -s $apt 2>/dev/null)" =~ "Status: install" ]] && apt_res="${apt_res}${apt}, "
    done
    if [ "$apt_res" != "" ]; then
      echo "Not installed apt paks: ${apt_res%?%?}! Can not continue with this script!"
      exit 1
    fi
  fi
  unset IFS
}

function convert_dhcpd_wifi {
  if [ -f "/etc/wpa_supplicant/wpa_supplicant.conf" ]; then
    local wifi_ssid=$(sed -n 's/^.*ssid=//p' /etc/wpa_supplicant/wpa_supplicant.conf | awk 'NR==1 {print $1}' | sed "s/['\"]//g")
    local wifi_key=$(sed -n 's/^.*psk=//p' /etc/wpa_supplicant/wpa_supplicant.conf | awk 'NR==1 {print $1}' | sed "s/['\"]//g")
    if [ -n "$wifi_ssid" ] && [ ! -e "/etc/NetworkManager/system-connections/$wifi_ssid.nmconnection" ]; then
      mkdir -p /etc/NetworkManager/system-connections
      cat >"/etc/NetworkManager/system-connections/$wifi_ssid.nmconnection" <<NMEOF
[connection]
id=$wifi_ssid
uuid=$(cat /proc/sys/kernel/random/uuid)
type=wifi
interface-name=wlan0
permissions=

[wifi]
mac-address-blacklist=
mode=infrastructure
ssid=$wifi_ssid

[wifi-security]
auth-alg=open
key-mgmt=wpa-psk
psk=$wifi_key

[ipv4]
dns-search=
method=auto

[ipv6]
addr-gen-mode=stable-privacy
dns-search=
method=auto

[proxy]

NMEOF
      chown -f 0:0 "/etc/NetworkManager/system-connections/$wifi_ssid.nmconnection"
      chmod -f 600 "/etc/NetworkManager/system-connections/$wifi_ssid.nmconnection"
    fi
  fi
}

function cmd_disable_cockpit() {
  if [[ ! "$(dpkg -s cockpit 2>/dev/null)" =~ "Status: install" ]]; then
    echo "cockpit server is not installed! Nothing do do here."
    echo "Please install package: cockpit"
    return
  fi
  systemctl disable cockpit.socket >/dev/null 2>&1
  systemctl stop cockpit.socket >/dev/null 2>&1
  echo "cockpit server is now deactive."
}

function cmd_enable_cockpit() {
  if [[ ! "$(dpkg -s cockpit 2>/dev/null)" =~ "Status: install" ]]; then
    echo "cockpit server is not installed! Nothing do do here."
    echo "Please install package: cockpit"
    return
  fi
  systemctl enable cockpit.socket >/dev/null 2>&1
  systemctl start cockpit.socket >/dev/null 2>&1
  echo "cockpit server is now active."
}

function cmd_disable_vnc() {
  if [ "$(which vncserver-x11-serviced)" == "" ]; then
    echo "RealVNC server is not installed! Nothing do do here."
    echo "Please install package: realvnc-vnc-server"
    return
  fi
  systemctl disable vncserver-x11-serviced.service >/dev/null 2>&1
  systemctl stop vncserver-x11-serviced.service >/dev/null 2>&1
  echo "RealVNC server is now deactive."
}

function cmd_enable_vnc() {
  if [ "$(which vncserver-x11-serviced)" == "" ]; then
    echo "RealVNC server is not installed! Nothing do do here."
    echo "Please install package: realvnc-vnc-server"
    return
  fi
  systemctl enable vncserver-x11-serviced.service >/dev/null 2>&1
  systemctl start vncserver-x11-serviced.service >/dev/null 2>&1
  echo "RealVNC server is now active."
}

function cmd_disable_vnc-web() {
  if [ "$(which vnc-web)" == "" ]; then
    echo "vnc-web server is not installed! Nothing do do here."
    return
  fi
  vnc-web -d >/dev/null 2>&1
  echo "vnc-web server is now deactive."
}

function cmd_enable_vnc-web() {
  if [ "$(which vnc-web)" == "" ]; then
    echo "vnc-web server is not installed! Nothing do do here."
    return
  fi
  vnc-web -e >/dev/null 2>&1
  echo "vnc-web server is now active."
}

function cmd_disable_ssh() {
  if [ "$(which ssh)" == "" ]; then
    echo "SSH server is not installed! Nothing do do here."
    echo "Please install package: ssh"
    return
  fi
  systemctl disable ssh.service >/dev/null 2>&1
  systemctl stop ssh.service >/dev/null 2>&1
  echo "SSH server is now deactive."
}

function cmd_enable_ssh() {
  if [ "$(which ssh)" == "" ]; then
    echo "SSH server is not installed! Nothing do do here."
    echo "Please install package: ssh"
    return
  fi
  ssh-keygen -A >/dev/null 2>&1
  systemctl enable ssh.service >/dev/null 2>&1
  systemctl start ssh.service >/dev/null 2>&1
  echo "SSH server is now active."
}

function cmd_disable_wlan_pwrsave() {
  if [ "$(ls /sys/class/ieee80211/*/device/net/ 2>/dev/null)" == "" ]; then
    cmd_enable_wlan_pwrsave >/dev/null 2>&1
    echo "No Wifi interface installed! Nothing do do here."
    return
  fi
  local interface
  systemctl disable wifi_powersave@.service >/dev/null 2>&1
  rm -f /etc/systemd/system/wifi_powersave@.service >/dev/null 2>&1
  cat <<EOF | sudo tee /etc/systemd/system/wifi_powersave@.service >/dev/null 2>&1
[Unit]
Description=Disable WiFi power save (%i)
After=sys-subsystem-net-devices-%i.device

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/iw dev %i set power_save off
ExecStop=/sbin/iw dev %i set power_save on

[Install]
WantedBy=sys-subsystem-net-devices-%i.device
EOF
  systemctl daemon-reload >/dev/null 2>&1
  for interface in $(ls /sys/class/ieee80211/*/device/net/ 2>/dev/null)
  do
    systemctl enable wifi_powersave@$interface.service >/dev/null 2>&1
    systemctl start wifi_powersave@$interface.service >/dev/null 2>&1
  done
  echo "Wifi powersafe are now disabled. (reboot resistant)"
}

function cmd_enable_wlan_pwrsave() {
  for interface in $(ls /sys/class/ieee80211/*/device/net/ 2>/dev/null)
  do
    systemctl stop wifi_powersave@$interface.service >/dev/null 2>&1
  done
  systemctl disable wifi_powersave@.service >/dev/null 2>&1
  rm -f /etc/systemd/system/wifi_powersave@.service >/dev/null 2>&1
  systemctl daemon-reload >/dev/null 2>&1
  echo "Wifi powersafe are now enabled (default)."
}

function cmd_use_networkmanager() {
  if [ "$(which NetworkManager)" == "" ]; then
    echo "NetworkManager is not installed! Nothing do do here."
    echo "Please install package: NetworkManager"
    return
  fi
  convert_dhcpd_wifi
  systemctl disable dhcpcd >/dev/null 2>&1
  systemctl enable NetworkManager >/dev/null 2>&1
  systemctl stop dhcpcd >/dev/null 2>&1
  systemctl start NetworkManager >/dev/null 2>&1
  echo "NetworkManager is now the default network interface control."
}

function cmd_use_dhcpcd() {
  if [ "$(which dhcpcd)" == "" ]; then
    echo "dhcpcd is not installed! Nothing do do here."
    echo "Please install package: dhcpcd"
    return
  fi
  systemctl disable NetworkManager >/dev/null 2>&1
  systemctl enable dhcpcd >/dev/null 2>&1
  systemctl stop NetworkManager >/dev/null 2>&1
  systemctl start dhcpcd >/dev/null 2>&1
  echo "dhcpcd is now the default network interface control."
}

function cmd_print_version() {
  echo "$SCRIPT_TITLE v$SCRIPT_VERSION"
}

function cmd_print_help() {
  echo "Usage: $SCRIPTNAME [OPTION]"
  echo "$SCRIPT_TITLE v$SCRIPT_VERSION"
  echo " "
  echo "--disable_vnc           disable RealVNC server"
  echo "--enable_vnc            enable RealVNC server"
  echo "--disable_vnc-web       disable vnc-web server"
  echo "--enable_vnc-web        enable vnc-web server"
  echo "--disable_cockpit       disable cockpit server"
  echo "--enable_cockpit        enable cockpit server"
  echo "--disable_ssh           disable ssh server"
  echo "--enable_ssh            enable ssh server"
  echo "--disable_wlan_pwrsave  disable wlan adapter powersafe setting (reboot resistant)"
  echo "--enable_wlan_pwrsave   enable wlan adapter powersafe setting"
  echo "--use_networkmanager    use NetworManager as network manager"
  echo "--use_dhcpcd            use dhcpcd5 as network manager"
  echo "-v, --version           print version info and exit"
  echo "-h, --help              print this help and exit"
  echo " "
  echo "Author: aragon25 <aragon25.01@web.de>"
}

[ "$CMD" != "version" ] && [ "$CMD" != "help" ] &&  do_check_start
[[ "$CMD" == "version" ]] && cmd_print_version
[[ "$CMD" == "help" ]] && cmd_print_help
[[ "$CMD" == "use_dhcpcd" ]] && cmd_use_dhcpcd
[[ "$CMD" == "use_networkmanager" ]] && cmd_use_networkmanager
[[ "$CMD" == "enable_wlan_pwrsave" ]] && cmd_enable_wlan_pwrsave
[[ "$CMD" == "disable_wlan_pwrsave" ]] && cmd_disable_wlan_pwrsave
[[ "$CMD" == "enable_ssh" ]] && cmd_enable_ssh
[[ "$CMD" == "disable_ssh" ]] && cmd_disable_ssh
[[ "$CMD" == "enable_vnc" ]] && cmd_enable_vnc
[[ "$CMD" == "disable_vnc" ]] && cmd_disable_vnc
[[ "$CMD" == "enable_vnc-web" ]] && cmd_enable_vnc-web
[[ "$CMD" == "disable_vnc-web" ]] && cmd_disable_vnc-web
[[ "$CMD" == "enable_cockpit" ]] && cmd_enable_cockpit
[[ "$CMD" == "disable_cockpit" ]] && cmd_disable_cockpit

exit $EXITCODE
