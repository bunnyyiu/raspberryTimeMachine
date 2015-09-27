#!/bin/bash

# This script setup Time Machine on Raspberry Pi.
# It assume /dev/sda2 is the paritation to export. 

function installNetatalk {
  sudo apt-get install git
  mkdir -p /tmp/code
  pushd /tmp/code > /dev/null
  git clone git://git.code.sf.net/p/netatalk/code netatalk
  pushd netatalk > /dev/null
  
  git checkout netatalk-3-1-7
  
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
  libtracker-sparql-0.14-dev \
  libtracker-miner-0.14-dev \
  bison \
  libltdl-dev \
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
  --with-tracker-pkgconfig-version=0.14
  
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

sudo apt-get install hfsplus hfsutils hfsprogs
sudo umount /dev/sda2
sudo mkdir -p /media/my_book
sudo chown pi:pi /media/my_book
sudo sed -i '/sda2/d' /etc/fstab
sudo bash -c "echo '/dev/sda2       /media/my_book   hfsplus force,noexec,defaults        0       0' >> /etc/fstab"
sudo mount -a

sudo sed -i 's/^hosts:.*$/hosts:          files mdns4_minimal [NOTFOUND=return] dns mdns4 mdns/' /etc/nsswitch.conf

sudo bash -c 'cat > /etc/avahi/services/afpd.service << "EOF"
<?xml version="1.0" standalone="no"?><!--*-nxml-*-->
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
    <name replace-wildcards="yes">%h</name>
    <service>
        <type>_afpovertcp._tcp</type>
        <port>548</port>
    </service>
    <service>
        <type>_device-info._tcp</type>
        <port>0</port>
        <txt-record>model=TimeCapsule</txt-record>
    </service>
</service-group>
EOF'

sudo bash -c 'cat > /usr/local/etc/afp.conf << "EOF"
[Global]
  log level = default:warn
  log file = /var/log/afpd.log
  mimic model = TimeCapsule6,106

[Time Machine]
  path = /media/my_book
  time machine = yes
EOF'

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
