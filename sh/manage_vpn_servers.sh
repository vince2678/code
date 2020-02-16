#!/bin/bash

VBOXPATH="/usr/bin/VBoxManage"
MONIT="/usr/bin/monit"

MAIN_VM="a17ca276-c09c-471e-ba3b-6fa4ccfb422e"
MAIN_VM_NUMBER=1
MAIN_IP="192.168.56.2"

SEARCH_REGEXP="Debian \[VPN\-[0-9]*\]"

BASE_CLONE_PREFIX="Debian [VPN-"
BASE_CLONE_SUFFIX="]"
BASE_IP="192.168.56."
BASE_SOCKS_PORT=1080
BASE_MONIT_SERVICE_PREFIX="socks-"

MAIN_MONIT_SERVICE="${BASE_MONIT_SERVICE_PREFIX}${BASE_SOCKS_PORT}"

MONIT_AVAILABLE_DIR="/etc/monit/conf-available"
MONIT_ENABLED_DIR="/etc/monit/conf-enabled"

GROUP_NAME="VPN"

MAX_POWEROFF_WAIT=30
MAX_POWERON_WAIT=30

function main_fn()
{
    case $1 in
        start)
            local VM_NUMBER=$2
            local IN_MONIT=$3
            local VM_NAME="${BASE_CLONE_PREFIX}${VM_NUMBER}${BASE_CLONE_SUFFIX}"
            local VM_SOCKS_PORT=$(($VM_NUMBER - 1 + $BASE_SOCKS_PORT))

            if [ -z "$VM_NUMBER" ]; then
                help
            fi

            is_valid_number $VM_NUMBER
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                exit 1
            fi

            startvm "$VM_NAME"

            # start monit services
            local monit_service="${BASE_MONIT_SERVICE_PREFIX}${VM_SOCKS_PORT}"

            if [ -z "$IN_MONIT" ]; then
                    echo "Starting monit service ${monit_service}..."
                    sudo ${MONIT} start ${monit_service}
            fi

            exit $?
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
                exit 1
            fi

            pausevm "$VM_NAME"
            exit $?
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
                exit 1
            fi

            resumevm "$VM_NAME"
            exit $?
            ;;
        stop)
            local VM_NUMBER=$2
            local IN_MONIT=$3
            local VM_NAME="${BASE_CLONE_PREFIX}${VM_NUMBER}${BASE_CLONE_SUFFIX}"
            local VM_SOCKS_PORT=$(($VM_NUMBER - 1 + $BASE_SOCKS_PORT))

            if [ -z "$VM_NUMBER" ]; then
                help
            fi

            is_valid_number $VM_NUMBER
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                exit 1
            fi

            waitpoweroff "$VM_NAME"

            # stop monit services
            if [ -z "$IN_MONIT" ]; then
                    local monit_service="${BASE_MONIT_SERVICE_PREFIX}${VM_SOCKS_PORT}"
                    echo "Stopping monit service ${monit_service}..."
                    sudo ${MONIT} stop ${monit_service}
            fi

            exit $?
            ;;
        delete)
            local VM_NUMBER=$2
            local VM_NAME="${BASE_CLONE_PREFIX}${VM_NUMBER}${BASE_CLONE_SUFFIX}"

            if [ -z "$VM_NUMBER" ]; then
                help
            elif [ "$VM_NUMBER" -eq "$MAIN_VM_NUMBER" ]; then
                echo "Refusing to remove main vm"
                exit 1
            fi

            is_valid_number $VM_NUMBER
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                exit 1
            fi

            local VM_SOCKS_PORT=$(($VM_NUMBER - 1 + $BASE_SOCKS_PORT))

            waitpoweroff "$VM_NAME"
            deletevm "$VM_NAME"

            # remove monit config
            local monit_service="${BASE_MONIT_SERVICE_PREFIX}${VM_SOCKS_PORT}"

            sudo ${MONIT} stop ${monit_service}
            sudo rm -f ${MONIT_AVAILABLE_DIR}/${monit_service}
            sudo rm -f ${MONIT_ENABLED_DIR}/${monit_service}
            sudo ${MONIT} reload

            exit $?
            ;;
        deploy)
            get_next_number
            local NEXT_NUMBER=$?

            if [ -z "$NEXT_NUMBER" ]; then
                echo "Could not get next vm number"
                exit 1
            fi

            local VM_NAME="${BASE_CLONE_PREFIX}${NEXT_NUMBER}${BASE_CLONE_SUFFIX}"
            local VM_HOST_IP="${BASE_IP}$(($NEXT_NUMBER+1))"
            local VM_SOCKS_PORT=$(($NEXT_NUMBER - 1 + $BASE_SOCKS_PORT))

            waitpoweroff "$MAIN_VM"

            # stop monit service
            sudo ${MONIT} stop ${MAIN_MONIT_SERVICE}

            # clone the main vm
            clonevm "$MAIN_VM" "$VM_NAME"
            if [ "$?" -ne 0 ]; then
                echo "Failed to clone vm"
                exit 1
            fi

            # wait for vm to be up on the main ip
            startvm "$VM_NAME"
            waitonip "$MAIN_IP"

            # copy the deploy script
            local TEMPFILE=$(tempfile)
            output_deploy_script "$TEMPFILE"
            scp $TEMPFILE root@${MAIN_IP}:$TEMPFILE

            # execute it
            ssh root@${MAIN_IP} "chmod +x $TEMPFILE"
            ssh root@${MAIN_IP} "$TEMPFILE $VM_NAME $VM_HOST_IP"

            # clean up
            ssh root@${MAIN_IP} "rm $TEMPFILE"
            rm $TEMPFILE

            # reboot the vm
            waitpoweroff "$VM_NAME"
            startvm "$VM_NAME"

            #make sure it's up
            waitonip "$VM_HOST_IP"

            # start the main
            startvm "$MAIN_VM"

            # copy monit script
            TEMPFILE=$(tempfile)
            output_monit_script "$VM_SOCKS_PORT" "$VM_HOST_IP" "$TEMPFILE"

            #we need root here
            local monit_service="${BASE_MONIT_SERVICE_PREFIX}${VM_SOCKS_PORT}"

            sudo cp $TEMPFILE ${MONIT_AVAILABLE_DIR}/${monit_service}
            sudo ln -s ${MONIT_AVAILABLE_DIR}/${monit_service} ${MONIT_ENABLED_DIR}

            # start monit services
            sudo ${MONIT} reload
            sudo ${MONIT} start ${monit_service}
            sudo ${MONIT} start ${MAIN_MONIT_SERVICE}

            echo "VM $VM_NAME deployed."

            rm $TEMPFILE
            ;;
        status)
            local VM_NUMBER=$2
            local VM_NAME="${BASE_CLONE_PREFIX}${VM_NUMBER}${BASE_CLONE_SUFFIX}"

            is_valid_number $VM_NUMBER
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                exit 1
            fi

            is_running "$VM_NAME"

            if [ "$?" -eq 0 ]; then
                echo "Running"
                exit 0
            else
                echo "Not running"
                exit 1
            fi
            ;;
        *)
            help
        ;;
    esac
}

function help()
{
    echo "Usage: $0 (deploy|destroy|start|pause|resume|stop|status) [VM_NUMBER] [IN_MONIT]"
    exit 1
}

function get_next_number {
    LAST=`VBoxManage list vms | grep -o "$SEARCH_REGEXP" | grep -o "[0-9]*" | sort | tail -n 1`
    return $(($LAST+1))
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
    local vm_numbers=`VBoxManage list vms | grep -o "$SEARCH_REGEXP" | grep -o "[0-9]*" | sort`
    echo $vm_numbers
}

# returns 0 if vm running, 1 otherwise
function is_running()
{
        output=`$VBOXPATH list runningvms | grep -oF "$1"`
        if [ "$output" == "$1" ]; then
            return 0
        else
            return 1
        fi
}

function startvm()
{
    echo "Starting vm ${1}..."
    $VBOXPATH startvm "$1" --type headless
    return $?
}

function deletevm()
{
    echo "Deleting vm ${1}..."
    $VBOXPATH unregistervm "$1" --delete
    return $?
}

# usage: clonevm to_clone clone_name
function clonevm()
{
    echo "Cloning vm ${1}..."
    $VBOXPATH clonevm "$1" --groups $GROUP_NAME \
       --mode machine --name "$2" --options link --register
    return $?
}

function resumevm()
{
    echo "Resuming vm ${1}..."
    $VBOXPATH controlvm "$1" resume
    return $?
}

function pausevm()
{
    echo "Pausing vm ${1}..."
    $VBOXPATH controlvm "$1" pause
    return $?
}

function hardresetvm()
{
    echo "Resetting vm ${1}..."
    $VBOXPATH controlvm "$1" reset
    return $?
}

function poweroffvm()
{
    echo "Powering off vm ${1}..."
    $VBOXPATH controlvm "$1" poweroff
    return $?
}

function acpipoweroffvm()
{
    $VBOXPATH controlvm "$1" acpipowerbutton
    return $?
}

# vm_ip
function waitonip()
{
    local status=1
    local start=`date +%s`
    while [ "$status" -ne 0 ]; do
        ssh root@${1} "echo Host $1 is now up." 2>/dev/null
        status=$?

        sleep 1
        local now=`date +%s`
        local runtime=$((now-start))
        if [ "$runtime" -gt $MAX_POWERON_WAIT ]; then
            return 1
        fi

    done
    return 0
}

function waitpoweroff()
{
    is_running "$1"
    local status=$?
    local start=`date +%s`

    echo "Attempting to shut down vm ${1}..."
    while [ "$status" -eq 0 ]; do
        acpipoweroffvm "$1"
        
        sleep 1
        local now=`date +%s`
        local runtime=$((now-start))
        if [ "$runtime" -gt $MAX_POWEROFF_WAIT ]; then
            break;
        fi

        is_running "$1"
        status=$?
    done

    is_running "$1"
    status=$?

    if [ "$status" -eq 0 ]; then
        poweroffvm "$1"
        #waitpoweroff $1 # run again for good measure
        return $?
    else
        echo "Successfully shut down vm ${1}."
        return 0
    fi
    return $?
}

# usage: output_monit_script port ip_address /path/to/file
function output_monit_script()
{
local user=vincent
local port=$1
local ip_addr=$2
local output=$3
cat << MONIT_SCRIPT > $output
check process socks-${port} with pidfile "/var/run/socks/socks-${port}.pid"
   group www
   group windscribe
   group socks-${port}
   start program = "/usr/bin/daemon -F /var/run/socks/socks-${port}.pid -u ${user} -n socks-${port} -- /usr/bin/ssh -D ${port} -q -C -N ${user}@${ip_addr}"
   stop program = "/usr/bin/daemon -F /var/run/socks/socks-${port}.pid --stop -n socks-${port}"
   if 4 restarts within 20 cycles then timeout
MONIT_SCRIPT
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
