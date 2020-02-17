#!/bin/bash

VBOXMANAGE="/usr/bin/VBoxManage"
SSH="/usr/bin/ssh"
DAEMON="/usr/bin/daemon"
RUNUSER="/sbin/runuser"

SCRIPT_USER="vincent"

MAIN_VM="Debian [VPN-1]"
MAIN_VM_NUMBER=1
MAIN_IP="192.168.56.2"
MAIN_SNAPSHOT="VPN_Snapshot"

SEARCH_REGEXP="Debian \[VPN\-[0-9]*\]"

BASE_CLONE_PREFIX="Debian [VPN-"
BASE_CLONE_SUFFIX="]"
HOSTNAME_PREFIX='debian-vpn-'

BASE_IP="192.168.56."
BASE_SOCKS_PORT=1080

SOCKS_PID_DIR="/run/socks/"
SOCKS_OWNER="vincent"
SOCKS_DAEMON_PREFIX="socks-"

GROUP_NAME="/VPN"

MAX_POWEROFF_WAIT=30
MAX_POWERON_WAIT=90

function main_fn()
{
    if [ "$USER" != "root" ]; then
        echo "Error: run this script as root"
        help
        return 1
    fi

    case $1 in
        start)
            local VM_NUMBER=$2
            local VM_NAME="${BASE_CLONE_PREFIX}${VM_NUMBER}${BASE_CLONE_SUFFIX}"

            if [ -z "$VM_NUMBER" ]; then
                help
            fi

            is_valid_number $VM_NUMBER
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                return 1
            fi

            startvm "$VM_NAME"
            if [ "$?" -ne 0 ]; then
                 echo "Failed to start vm $VM_NAME"
                 return 1
            fi

            waitonip "$MAIN_IP"
            if [ "$?" -ne 0 ]; then
                echo "Timed out waiting for vm $VM_NAME to start"
                return 1
            fi

            main_fn start-proxy "$VM_NUMBER"
            return $?
            ;;
        check-ip)
            local VM_NUMBER=$2

            is_valid_number $VM_NUMBER
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                return 1
            fi

            ip=`getpublicip $VM_NUMBER`
            status=$?
            if [ "$status" -eq 1 ]; then
                echo "Failed to get public ip"
                return $status
            fi

            echo $ip
            return 0
            ;;
        pause)
            local VM_NUMBER=$2
            local VM_NAME="${BASE_CLONE_PREFIX}${VM_NUMBER}${BASE_CLONE_SUFFIX}"

            if [ -z "$VM_NUMBER" ]; then
                help
            fi

            is_valid_number $VM_NUMBER
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                return 1
            fi

            pausevm "$VM_NAME"
            status=$?
            if [ "$status" -ne 0 ]; then
                echo "Failed to pause $VM_NAME"
                return $status
            fi

            main_fn stop-proxy "$VM_NUMBER"
            return $?
            ;;
        resume)
            local VM_NUMBER=$2
            local VM_NAME="${BASE_CLONE_PREFIX}${VM_NUMBER}${BASE_CLONE_SUFFIX}"

            if [ -z "$VM_NUMBER" ]; then
                help
            fi

            is_valid_number $VM_NUMBER
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                return 1
            fi

            resumevm "$VM_NAME"
            status=$?
            if [ "$status" -ne 0 ]; then
                echo "Failed to resume $VM_NAME"
                return $status
            fi

            main_fn start-proxy "$VM_NUMBER"
            return $?
            ;;
        stop)
            local VM_NUMBER=$2
            local VM_NAME="${BASE_CLONE_PREFIX}${VM_NUMBER}${BASE_CLONE_SUFFIX}"

            if [ -z "$VM_NUMBER" ]; then
                help
            fi

            is_valid_number $VM_NUMBER
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                return 1
            fi

            waitpoweroff "$VM_NUMBER"
            if [ "$?" -ne 0 ]; then
                echo "Failed to shut down vm $VM_NAME."
                return 1
            fi

            main_fn stop-proxy "$VM_NUMBER"
            return $?
            ;;
        start-proxy)
            local VM_NUMBER=$2

            if [ -z "$VM_NUMBER" ]; then
                help
            fi

            is_valid_number $VM_NUMBER
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                return 1
            fi

            issocksactive "$VM_NUMBER"
            status=$?
            if [ "$status" -ne 0 ]; then
                startsocksproxy "$VM_NUMBER"
                return $status
            fi
            return 0
            ;;
        stop-proxy)
            local VM_NUMBER=$2

            if [ -z "$VM_NUMBER" ]; then
                help
            fi

            is_valid_number $VM_NUMBER
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                return 1
            fi

            issocksactive "$VM_NUMBER"
            status=$?
            if [ "$status" -eq 0 ]; then
                stopsocksproxy "$VM_NUMBER"
                return $status
            fi
            return 0
            ;;
        delete)
            local VM_NUMBER=$2
            local VM_NAME="${BASE_CLONE_PREFIX}${VM_NUMBER}${BASE_CLONE_SUFFIX}"

            if [ -z "$VM_NUMBER" ]; then
                help
            elif [ "$VM_NUMBER" -eq "$MAIN_VM_NUMBER" ]; then
                echo "Refusing to remove main vm"
                return 1
            fi

            main_fn stop "$VM_NUMBER"
            if [ "$?" -ne 0 ]; then
                return 1
            fi

            deletevm "$VM_NAME"
            status=$?
            if [ "$status" -ne 0 ]; then
                echo "Failed to delete vm ${VM_NAME}."
                return $status
            fi
            ;;
        deploy)
            local VM_NUMBER=`get_next_number`
            if [ -z "$VM_NUMBER" ]; then
                echo "Could not get next vm number"
                return 1
            fi

            local VM_NAME="${BASE_CLONE_PREFIX}${VM_NUMBER}${BASE_CLONE_SUFFIX}"
            local VM_HOSTNAME="${HOSTNAME_PREFIX}$(($VM_NUMBER+1))"
            local VM_HOST_IP="${BASE_IP}$(($VM_NUMBER+1))"

            main_fn stop "$MAIN_VM_NUMBER"
            if [ "$?" -ne 0 ]; then
                return 1
            fi

            local snapshot=`$RUNUSER -u $SCRIPT_USER -- $VBOXMANAGE snapshot "$MAIN_VM" list | grep -oF "$MAIN_SNAPSHOT"`
            if [ -z "$snapshot" ]; then
                $RUNUSER -u $SCRIPT_USER -- $VBOXMANAGE snapshot "$MAIN_VM" take "$MAIN_SNAPSHOT"
            fi

            # clone the main vm
            clonevm "$MAIN_VM" "$VM_NAME"
            if [ "$?" -ne 0 ]; then
                echo "Failed to clone vm"
                return 1
            fi

            # wait for vm to be up on the main ip
            startvm "$VM_NAME"
            if [ "$?" -ne 0 ]; then
                 echo "Failed to start cloned vm"
                 main_fn delete "$VM_NUMBER"
                 main_fn start "$MAIN_VM_NUMBER"
                 return 1
            fi

            waitonip "$MAIN_IP"
            if [ "$?" -ne 0 ]; then
                echo "Timed out waiting for vm"

                waitpoweroff "$VM_NUMBER"
                if [ "$?" -eq 0 ]; then
                    main_fn delete "$VM_NUMBER"
                else
                    echo "Failed to shut down vm $VM_NAME."
                fi

                main_fn start "$MAIN_VM_NUMBER"
                return 1
            fi

            # copy the deploy script
            local TEMPFILE=$(tempfile)
            output_deploy_script "$TEMPFILE"
            scp $TEMPFILE root@${MAIN_IP}:$TEMPFILE

            # execute it
            $RUNUSER -u $SCRIPT_USER -- $SSH root@${MAIN_IP} "chmod +x $TEMPFILE"
            $RUNUSER -u $SCRIPT_USER -- $SSH root@${MAIN_IP} "$TEMPFILE $VM_HOSTNAME $VM_HOST_IP"

            # clean up
            $RUNUSER -u $SCRIPT_USER -- $SSH root@${MAIN_IP} "rm $TEMPFILE"
            rm $TEMPFILE

            # reboot the vm
            waitpoweroff "$VM_NUMBER"
            if [ "$?" -ne 0 ]; then
                echo "Failed to shut down vm ${VM_NAME}."
                return 1
            fi

            main_fn start "$VM_NUMBER"
            if [ "$?" -ne 0 ]; then
                 echo "Failed to start cloned vm"
                 main_fn delete "$VM_NUMBER"
                 return 1
            fi

            # start the main
            main_fn start "$MAIN_VM_NUMBER"
            if [ "$?" -ne 0 ]; then
                 echo "Failed to start main vm"
            fi

            echo "VM ${VM_NAME} deployed."
            return 0
            ;;
        status)
            local VM_NUMBER=$2
            local VM_NAME="${BASE_CLONE_PREFIX}${VM_NUMBER}${BASE_CLONE_SUFFIX}"
            local VM_HOST_IP="${BASE_IP}$(($VM_NUMBER+1))"
            local socks_port=$(($VM_NUMBER - 1 + $BASE_SOCKS_PORT))

            is_valid_number $VM_NUMBER
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                return 1
            fi

            is_running "$VM_NAME"
            status=$?

            if [ "$status" -eq 0 ]; then
                issocksactive $VM_NUMBER
                if [ "$?" -eq 0 ]; then
                    ip=`getpublicip $VM_NUMBER`

                    echo "\"${VM_NAME}\": [RUNNING] *:${socks_port}:${VM_HOST_IP} -> $ip"
                    return 0
                else
                    echo "\"${VM_NAME}\": [RUNNING] (tunnel inactive)"
                    return 1
                fi
            else
                echo "\"${VM_NAME}\": [NOT RUNNING]"
                return 1
            fi
            ;;
        status-all)
            status=0
            for vm_number in `get_vm_numbers`; do
                main_fn status $vm_number
                status=$(($status + $?))
            done
            return $status
            ;;
        *)
            help
        ;;
    esac
}

function help()
{
    echo "Usage: $0 (deploy|delete|check-ip|start-proxy|stop-proxy|start|pause|resume|stop|status|status-all) [VM_NUMBER]"
    exit 1
}

function get_next_number {
    LAST=`$RUNUSER -u $SCRIPT_USER -- $VBOXMANAGE list vms | grep -o "$SEARCH_REGEXP" | grep -o "[0-9]*" | sort | tail -n 1`
    echo $(($LAST+1))
}

# Usage: is_valid_number vm_number
function is_valid_number {
    if [ -z "$1" ]; then
        return 1
    fi

    for i in `get_vm_numbers`; do
        if [ "$i" -eq "$1" ]; then
            return 0
        fi
    done
    return 1
}

function get_vm_numbers {
    local vm_numbers=`$RUNUSER -u $SCRIPT_USER -- $VBOXMANAGE list vms | grep -o "$SEARCH_REGEXP" | grep -o "[0-9]*" | sort`
    echo $vm_numbers
}

# returns 0 if vm running, 1 otherwise
function is_running()
{
    output=`$RUNUSER -u $SCRIPT_USER -- $VBOXMANAGE list runningvms | grep -oF "$1"`
    if [ "$output" == "$1" ]; then
        return 0
    else
        return 1
    fi
}

function startvm()
{
    is_running "$1"
    if [ "$?" -eq 0 ]; then
       return 0;
    fi
    echo "Starting vm ${1}..."
    $RUNUSER -u $SCRIPT_USER -- $VBOXMANAGE startvm "$1" --type headless
    return $?
}

# usage: getuplicip vm_number
function getpublicip()
{
    local vm_number=$1
    local vm_host_ip="${BASE_IP}$(($vm_number+1))"
    local vm_name="${BASE_CLONE_PREFIX}${vm_number}${BASE_CLONE_SUFFIX}"

    is_running "$vm_name"
    if [ "$?" -eq 1 ]; then
       return 1;
    fi
    $RUNUSER -u $SCRIPT_USER -- $SSH root@${vm_host_ip} curl http://ifconfig.me/ip 2>/dev/null
    return $?
}

#usage startsocksproxy vm_number
# return 0 on success, 1 otherwise
function startsocksproxy()
{
    local vm_number=$1
    local socks_port=$(($vm_number - 1 + $BASE_SOCKS_PORT))
    local socks_service="${SOCKS_DAEMON_PREFIX}${socks_port}"
    local vm_host_ip="${BASE_IP}$(($vm_number+1))"

    if ! [ -d "$SOCKS_PID_DIR" ]; then
        mkdir $SOCKS_PID_DIR
        chown ${SOCKS_OWNER}:${SOCKS_OWNER} $SOCKS_PID_DIR
    fi

    echo "Starting socks tunnel on port ${socks_port} through ${vm_host_ip}..."
    $DAEMON -F ${SOCKS_PID_DIR}/${socks_service}.pid \
            -u ${SOCKS_OWNER} -n ${socks_service} -- \
            $SSH -D ${socks_port} -q -C -N ${SOCKS_OWNER}@${vm_host_ip}

    return $?
}

#usage stopsocksproxy vm_number
# return 0 on success, 1 otherwise
function stopsocksproxy()
{
    local vm_number=$1
    local socks_port=$(($vm_number - 1 + $BASE_SOCKS_PORT))
    local socks_service="${SOCKS_DAEMON_PREFIX}${socks_port}"
    local vm_host_ip="${BASE_IP}$(($vm_number+1))"

    if ! [ -d "$SOCKS_PID_DIR" ]; then
        mkdir $SOCKS_PID_DIR
        chown ${SOCKS_OWNER}:${SOCKS_OWNER} $SOCKS_PID_DIR
        return 0
    fi

    echo "Stopping socks tunnel on port ${socks_port} through ${vm_host_ip}..."
    $DAEMON -F ${SOCKS_PID_DIR}/${socks_service}.pid \
            -n ${socks_service} --stop

    return $?
}

#usage issocksactive vm_number
# return 0 if running, 1 otherwise
function issocksactive()
{
    local vm_number=$1
    local socks_port=$(($vm_number - 1 + $BASE_SOCKS_PORT))
    local socks_service="${SOCKS_DAEMON_PREFIX}${socks_port}"

    if ! [ -d "$SOCKS_PID_DIR" ]; then
        mkdir $SOCKS_PID_DIR
        chown ${SOCKS_OWNER}:${SOCKS_OWNER} $SOCKS_PID_DIR
        return 1
    fi

    $DAEMON -F ${SOCKS_PID_DIR}/${socks_service}.pid \
            -n ${socks_service} --running

    return $?
}

#usage deletevm vm_name
function deletevm()
{
    echo "Deleting vm ${1}..."
    $RUNUSER -u $SCRIPT_USER -- $VBOXMANAGE unregistervm "$1" --delete
    return $?
}

# usage: clonevm to_clone clone_name
function clonevm()
{
    echo "Cloning vm ${1}..."
    $RUNUSER -u $SCRIPT_USER -- $VBOXMANAGE clonevm "$1" --groups $GROUP_NAME \
       --mode machine --name "$2" --options link \
       --register --snapshot $MAIN_SNAPSHOT
    return $?
}

function resumevm()
{
    echo "Resuming vm ${1}..."
    $RUNUSER -u $SCRIPT_USER -- $VBOXMANAGE controlvm "$1" resume
    return $?
}

function pausevm()
{
    echo "Pausing vm ${1}..."
    $RUNUSER -u $SCRIPT_USER -- $VBOXMANAGE controlvm "$1" pause
    return $?
}

function hardresetvm()
{
    echo "Resetting vm ${1}..."
    $RUNUSER -u $SCRIPT_USER -- $VBOXMANAGE controlvm "$1" reset
    return $?
}

# usage: poweroffvm vm_name
function poweroffvm()
{
    local VM_NAME=$1
    echo "Powering off vm ${VM_NAME}..."
    $RUNUSER -u $SCRIPT_USER -- $VBOXMANAGE controlvm "$VM_NAME" poweroff
    return $?
}

# usage: acpipoweroffvm vm_number
function acpipoweroffvm()
{
    local VM_NUMBER=$1
    local VM_HOST_IP="${BASE_IP}$(($VM_NUMBER+1))"

    $RUNUSER -u $SCRIPT_USER -- $SSH root@${VM_HOST_IP} "init 0"
    return $?
}

# usage: waitonip vm_ip
function waitonip()
{
    local status=1
    local start=`date +%s`
    while [ "$status" -ne 0 ]; do
        $RUNUSER -u $SCRIPT_USER -- $SSH root@${1} "echo Host $1 is now up." 2>/dev/null
        status=$?

        sleep 5
        local now=`date +%s`
        local runtime=$((now-start))
        if [ "$runtime" -gt $MAX_POWERON_WAIT ]; then
            return 1
        fi
    done
    return 0
}

# usage: waitpoweroffvm vm_number
function waitpoweroff()
{
    local VM_NUMBER=$1
    local VM_NAME="${BASE_CLONE_PREFIX}${VM_NUMBER}${BASE_CLONE_SUFFIX}"

    is_running "$VM_NAME"
    if [ "$?" -eq 0 ]; then
        return 0
    fi

    echo "Attempting to shut down vm ${VM_NAME}..."
    acpipoweroffvm "$VM_NUMBER"

    local start=`date +%s`
    local runtime=0
    while [ "$runtime" -lt "$MAX_POWEROFF_WAIT" ]; do
        is_running "$VM_NAME"
        if [ "$?" -ne 0 ]; then
            echo "Successfully shut down vm ${1}."
        return 0
        fi

        sleep 2
        now=`date +%s`
        runtime=$((now-start))
    done

    echo "Failed acpi shutdown, attempting hard poweroff..."
    poweroffvm "$VM_NAME"
    return $?
}

# arg 1: path to output
function output_deploy_script()
{
cat << DEPLOY_SCRIPT > $1
#!/bin/bash

ETC_ROOT=/etc

if [ -z "\$1" ] || [ -z "\$2" ]; then
   echo "Usage: \$0 VM_HOSTNAME VM_HOST_IP"
   exit 1
fi

VM_HOSTNAME=\$1
VM_HOST_IP=\$2

cat << EOF > \$ETC_ROOT/hosts
127.0.0.1    localhost
127.0.1.1    \${VM_HOSTNAME}.msm8916.com    \${VM_HOSTNAME}

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

cat << EOF > \$ETC_ROOT/hostname
\${VM_HOSTNAME}
EOF

cat << EOF > \$ETC_ROOT/network/interfaces
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
    address \${VM_HOST_IP}/24
EOF
DEPLOY_SCRIPT
}

main_fn $1 $2 $3 $4 $5 $6
exit $?
