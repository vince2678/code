#!/bin/bash

ETC_ROOT=/etc

if [ -z "$1" ] || [ -z "$2" ]; then
   echo "Usage: $0 VM_HOSTNAME VM_HOST_IP"
   exit 1
fi

VM_HOSTNAME=$1
VM_HOST_IP=$2

cat << EOF > $ETC_ROOT/hosts
127.0.0.1	localhost
127.0.1.1	${VM_HOSTNAME}.msm8916.com	${VM_HOSTNAME}

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

cat << EOF > $ETC_ROOT/hostname
${VM_HOSTNAME}
EOF

cat << EOF > $ETC_ROOT/network/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
allow-hotplug enp0s3
iface enp0s3 inet dhcp

allow-hotplug enp0s8
iface enp0s8 inet static
    address ${VM_HOST_IP}/24
EOF
