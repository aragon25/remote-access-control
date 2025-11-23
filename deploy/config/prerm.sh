#!/bin/bash
if [ -f "/usr/bin/remote-access-control" ] && [ "$1" == "remove" ]; then
  /usr/bin/remote-access-control --enable_wlan_pwrsave >/dev/null 2>&1
fi
exit 0