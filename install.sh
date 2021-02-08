#!/bin/bash

set -e
set -u

[[ $UID -ne 0 ]] && {
  echo "$0 must be run as root"
  exit 1
}

logfile="./build.log"
: > "${logfile}"
exec &> >(tee "${logfile}")

systemctl stop mhvtl.target || :
systemctl stop mhvtl-load-modules.service || :

systemctl disable mhvtl.target || :
systemctl disable mhvtl-load-modules.service || :

# make clean does not remove everything
echo "Cleanup working copy (y/n)?"
if read -r -n 1 answer; then
  if [ "${answer}" = "y" ]; then
    git clean -dxf
  fi
fi

make
make install

cd kernel
make clean
make
make install

cd -

wrong_path="/usr/lib/systemd/system-generators"
right_path="/lib/systemd/system-generators"

if ! [ -f "${wrong_path}/mhvtl-device-conf-generator" ] &&
     [ -f "${right_path}/mhvtl-device-conf-generator" ]; then
  mv "${wrong_path}/mhvtl-device-conf-generator" \
    "${right_path}/mhvtl-device-conf-generator"
fi

systemctl daemon-reload
systemctl enable mhvtl.target
systemctl enable mhvtl-load-modules.service

systemctl start mhvtl.target
systemctl start mhvtl-load-modules.service

sleep 5
lsscsi -g

echo
echo "Ready"
echo
