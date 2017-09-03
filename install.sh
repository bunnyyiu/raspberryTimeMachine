#!/bin/bash

# This script setup Time Machine on Raspberry Pi.

function installNetatalk {
  sudo apt-get install git
  mkdir -p /tmp/code
  pushd /tmp/code > /dev/null
  git clone git://git.code.sf.net/p/netatalk/code netatalk
  pushd netatalk > /dev/null

  git checkout netatalk-3.1.8

  sudo apt-get install build-essential \
  libevent-dev \
  libssl-dev \
  libgcrypt11-dev \
  libkrb5-dev \
  libpam0g-dev \
  libwrap0-dev \
  libdb-dev \
  libtdb-dev \
  libmysqlclient-dev \
  libavahi-client-dev \
  libacl1-dev \
  libldap2-dev \
  libcrack2-dev \
  systemtap-sdt-dev \
  libdbus-1-dev \
  libdbus-glib-1-dev \
  libglib2.0-dev \
  tracker \
  libtracker-sparql-1.0-dev \
  libtracker-miner-1.0-dev \
  bison \
  libltdl-dev \
  autoconf \
  libtool-bin \
  automake \
  avahi-daemon -y

  ./bootstrap
  ./configure \
  --with-init-style=debian-sysv \
  --without-libevent \
  --without-tdb \
  --with-cracklib \
  --enable-krbV-uam \
  --with-pam-confdir=/etc/pam.d \
  --with-dbus-sysconf-dir=/etc/dbus-1/system.d \
  --with-tracker-pkgconfig-version=1.0

  make
  sudo make install
  make clean
  popd > /dev/null
  popd > /dev/null
  afpd -V

  rm -rf /tmp/code
}

sudo apt-get update
sudo apt-get upgrade -y

if ! command -v netatalk > /dev/null; then
  installNetatalk
fi

read -p "Please enter the usb storage device name, default is sda1" deviceName
if [ "$deviceName" == "" ]; then
  deviceName="sda1"
fi
sudo umount /dev/$deviceName
sudo mkdir -p /media/my_book
sudo chown pi:pi /media/my_book
deviceUUID=`ls -l /dev/disk/by-uuid/ | grep sda1 | awk '{print $9}'`

if [ "$deviceUUID" == "" ]; then
  exit 1
fi
sudo sed -i "/^\/dev\/$deviceName/d" /etc/fstab
sudo sed -i "/^UUID=$deviceUUID/d" /etc/fstab
seqFSCK=$((`cat /etc/fstab | grep -v '^#' | awk '{print $6}' | sort | tail -1` + 1))
sudo bash -c "echo 'UUID=$deviceUUID /media/my_book ext4 noexec,defaults,nofail 0 $seqFSCK' >> /etc/fstab"
sudo mount -a

sudo sed -i 's/^hosts:.*$/hosts:          files mdns4_minimal [NOTFOUND=return] dns mdns4 mdns/' /etc/nsswitch.conf

interfaces=`ip -o link show | awk -F': ' '{print $2}' | \
sed /lo/d | sed -n -e 'H;${x;s/\n/,/g;s/^,//;p;}'`

sudo bash -c "cat > /usr/local/etc/afp.conf << 'EOF'
[Global]
  apf interfaces = $interfaces
  log level = default:warn
  log file = /var/log/afpd.log
  mimic model = TimeCapsule6,106
  vol dbpath = /var/netatalk/CNID/$u/$v/

[Time Machine]
  path = /media/my_book
  time machine = yes
EOF"

sudo mkdir -p "/var/netatalk/CNID/pi/Time Machine/"

sudo service avahi-daemon restart
sudo service netatalk restart

sudo update-rc.d avahi-daemon defaults
sudo update-rc.d netatalk defaults

# spin down harddisk after 20 minutes
sudo apt-get install hdparm
sudo bash -c 'cat >> /etc/hdparm.conf << "EOF"
command_line {
  hdparm -S 240 /dev/sda
}
EOF'
