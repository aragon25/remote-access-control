#!/bin/bash
if [ "$(which remote-access-control)" != "" ] && [ "$1" == "install" ]; then
  echo "The command \"remote-access-control\" is already present. Can not install this."
  echo "File: \"$(which remote-access-control)\""
  exit 1
fi
exit 0