#!/bin/bash

VBOXMANAGE="/usr/bin/VBoxManage"
SSH="/usr/bin/ssh -o ConnectTimeout=1 -o StrictHostKeyChecking=no"
SCP="/usr/bin/scp -o StrictHostKeyChecking=no"
DAEMON="/usr/bin/daemon"
REALPATH="/usr/bin/realpath"

SCRIPT_USER="vincent"

MAIN_VM="Debian [VPN-0]"
MAIN_VM_NUMBER=0
MAIN_IP="192.168.56.240"
MAIN_SNAPSHOT="VPN_Snapshot"

SEARCH_REGEXP="Debian \[VPN\-[0-9]*\]"

BASE_CLONE_PREFIX="Debian [VPN-"
BASE_CLONE_SUFFIX="]"
HOSTNAME_PREFIX='debian-vpn-'

BASE_IP="192.168.56."
BASE_SOCKS_PORT=1080

SOCKS_PID_DIR="/run/user/$UID/socks/"
SOCKS_DAEMON_PREFIX="socks-"

GROUP_NAME="/VPN"

MAX_POWEROFF_WAIT=30
MAX_POWERON_WAIT=90

function main_fn()
{
    if [ -z "$SCRIPT_USER" ]; then
        SCRIPT_USER=$USER
        SCRIPT_UID=$UID
    else
        SCRIPT_UID=`grep "$SCRIPT_USER" /etc/passwd|cut -d':' -f 3`
        SOCKS_PID_DIR="/run/user/${SCRIPT_UID}/socks/"
    fi

    case "$1" in
        "connect")
            local vm_number=$2
            local vm_host_ip="${BASE_IP}$(($vm_number+1))"

            if [ -z "$vm_number" ]; then
                help
            fi

            is_valid_number $vm_number
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                return 1
            fi

            $SSH ${SCRIPT_USER}@${vm_host_ip}
            return $?
            ;;
        "start")
            local vm_number=$2
            local vm_name="${BASE_CLONE_PREFIX}${vm_number}${BASE_CLONE_SUFFIX}"
            local vm_host_ip="${BASE_IP}$(($vm_number+1))"

            if [ -z "$vm_number" ]; then
                help
            fi

            is_valid_number $vm_number
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                return 1
            fi

            startvm "$vm_number"
            if [ "$?" -ne 0 ]; then
                 echo "Failed to start vm $vm_name"
                 return 1
            fi

            waitonip "$vm_host_ip"
            if [ "$?" -ne 0 ]; then
                echo "Timed out waiting for vm $vm_name to start on ip $vm_host_ip"
                return 1
            fi

            main_fn start-proxy "$vm_number"
            return $?
            ;;
        "start-all")
            status=0
            for vm_number in `get_vm_numbers`; do
                main_fn start $vm_number
                status=$(($status + $?))
            done
            return $status
            ;;
        "check-ip")
            local vm_number=$2

            is_valid_number $vm_number
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                return 1
            fi

            ip=`getpublicip $vm_number`
            status=$?
            if [ "$status" -eq 1 ]; then
                echo "Failed to get public ip"
                return $status
            fi

            echo $ip
            return 0
            ;;
        "pause")
            local vm_number=$2
            local vm_name="${BASE_CLONE_PREFIX}${vm_number}${BASE_CLONE_SUFFIX}"

            if [ -z "$vm_number" ]; then
                help
            fi

            is_valid_number $vm_number
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                return 1
            fi

            local paused=`is_paused "$vm_number"`
            if [ "$paused" == "true" ]; then
                return 0
            fi

            local running=`is_running "$vm_number"`
            if [ "$running" == "false" ]; then
                echo "VM ${vm_name} is not running"
                return 1
            fi

            pausevm "$vm_name"
            status=$?
            if [ "$status" -ne 0 ]; then
                echo "Failed to pause $vm_name"
                return $status
            fi

            main_fn stop-proxy "$vm_number"
            return $?
            ;;
        "pause-all")
            status=0
            for vm_number in `get_vm_numbers`; do
                main_fn pause $vm_number
                status=$(($status + $?))
            done
            return $status
            ;;
        "resume")
            local vm_number=$2
            local vm_name="${BASE_CLONE_PREFIX}${vm_number}${BASE_CLONE_SUFFIX}"

            if [ -z "$vm_number" ]; then
                help
            fi

            is_valid_number $vm_number
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                return 1
            fi

            local paused=`is_paused "$vm_number"`
            if [ "$paused" == "false" ]; then
                echo "VM ${vm_name} is not paused"
                return 1
            fi

            resumevm "$vm_name"
            status=$?
            if [ "$status" -ne 0 ]; then
                echo "Failed to resume $vm_name"
                return $status
            fi

            main_fn start-proxy "$vm_number"
            return $?
            ;;
        "resume-all")
            status=0
            for vm_number in `get_vm_numbers`; do
                main_fn resume $vm_number
                status=$(($status + $?))
            done
            return $status
            ;;
        "stop")
            local vm_number=$2
            local vm_name="${BASE_CLONE_PREFIX}${vm_number}${BASE_CLONE_SUFFIX}"

            if [ -z "$vm_number" ]; then
                help
            fi

            is_valid_number $vm_number
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                return 1
            fi

            local paused=`is_paused "$vm_number"`
            if [ "$paused" == "true" ]; then
                main_fn resume "$vm_number"

                if [ "$?" -ne 0 ]; then
                    echo "Failed to resume VM ${vm_name}"
                fi
            fi

            waitpoweroff "$vm_number"
            if [ "$?" -ne 0 ]; then
                echo "Failed to shut down vm $vm_name."
                return 1
            fi

            main_fn stop-proxy "$vm_number"
            return $?
            ;;
        "stop-all")
            # quick shutdown first
            for vm_number in `get_vm_numbers`; do
            local running=`is_running "$vm_number"`
            if [ "$running" == "true" ]; then
                acpipoweroffvm $vm_number
            fi
            done

            status=0
            for vm_number in `get_vm_numbers`; do
                main_fn stop $vm_number
                status=$(($status + $?))
            done
            return $status
            ;;
        "start-proxy")
            local vm_number=$2

            if [ -z "$vm_number" ]; then
                help
            fi

            is_valid_number $vm_number
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                return 1
            fi

            issocksactive "$vm_number"
            status=$?
            if [ "$status" -ne 0 ]; then
                startsocksproxy "$vm_number"
                status=$?
                if [ "$status" -eq 0 ]; then
                    echo "Started socks proxy."
                else
                    echo "Failed to start socks proxy."
                fi
                return $status
            fi
            return 0
            ;;
        "stop-proxy")
            local vm_number=$2

            if [ -z "$vm_number" ]; then
                help
            fi

            is_valid_number $vm_number
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                return 1
            fi

            issocksactive "$vm_number"
            status=$?
            if [ "$status" -eq 0 ]; then
                stopsocksproxy "$vm_number"
                status=$?
                if [ "$status" -eq 0 ]; then
                    echo "Stopped socks proxy."
                else
                    echo "Failed to stop socks proxy."
                fi
                return $status
            fi
            return 0
            ;;
        "delete")
            local vm_number=$2
            local vm_name="${BASE_CLONE_PREFIX}${vm_number}${BASE_CLONE_SUFFIX}"

            if [ -z "$vm_number" ]; then
                help
            elif [ "$vm_number" -eq "$MAIN_VM_NUMBER" ]; then
                echo "Refusing to remove main vm"
                return 1
            fi

            main_fn stop "$vm_number"
            if [ "$?" -ne 0 ]; then
                return 1
            fi

            deletevm "$vm_name"
            status=$?
            if [ "$status" -ne 0 ]; then
                echo "Failed to delete vm ${vm_name}."
                return $status
            fi

            return $?
            ;;
        "deploy")
            local vm_number=`get_next_number`
            if [ -z "$vm_number" ]; then
                echo "Could not get next vm number"
                return 1
            fi

            local vm_name="${BASE_CLONE_PREFIX}${vm_number}${BASE_CLONE_SUFFIX}"
            local vm_hostname="${HOSTNAME_PREFIX}$(($vm_number))"
            local vm_host_ip="${BASE_IP}$(($vm_number+1))"

            main_running=`is_running "$MAIN_VM_NUMBER"`

            main_fn stop "$MAIN_VM_NUMBER"
            if [ "$?" -ne 0 ]; then
                return 1
            fi

            local snapshot=`$VBOXMANAGE snapshot "$MAIN_VM" list | grep -oF "$MAIN_SNAPSHOT"`
            if [ -z "$snapshot" ]; then
                $VBOXMANAGE snapshot "$MAIN_VM" take "$MAIN_SNAPSHOT"
            fi

            # clone the main vm
            clonevm "$MAIN_VM" "$vm_name"
            if [ "$?" -ne 0 ]; then
                echo "Failed to clone vm"
                return 1
            fi

            # wait for vm to be up on the main ip
            startvm "$vm_number"
            if [ "$?" -ne 0 ]; then
                 echo "Failed to start cloned vm"
                 main_fn delete "$vm_number"
                 main_fn start "$MAIN_VM_NUMBER"
                 return 1
            fi

            waitonip "$MAIN_IP"
            if [ "$?" -ne 0 ]; then
                echo "Timed out waiting for vm"

                waitpoweroff "$vm_number"
                if [ "$?" -eq 0 ]; then
                    main_fn delete "$vm_number"
                else
                    echo "Failed to shut down vm $vm_name."
                fi

                main_fn start "$MAIN_VM_NUMBER"
                return 1
            fi

            # copy the deploy script
            local tempfile=$(tempfile --mode 644)
            output_deploy_script "$tempfile"
            $SCP $tempfile root@${MAIN_IP}:$tempfile

            status=$?
            if [ "$status" -eq 0 ]; then
                # execute it
                $SSH root@${MAIN_IP} "chmod +x $tempfile"
                $SSH root@${MAIN_IP} "$tempfile $vm_hostname $vm_host_ip"

                # clean up
                $SSH root@${MAIN_IP} "rm $tempfile"

                # shutdown the vm
                waitpoweroff "$vm_number" "$MAIN_IP"
                status=$?
            else
                echo "Failed to copy setup script to $vm_name"
                main_fn delete "$vm_number"
            fi

            rm $tempfile

            if [ "$status" -eq 0 ]; then
                main_fn start "$vm_number"
                status=$?
            fi

            if [ "$status" -eq 0 ]; then
                echo "VM ${vm_name} deployed."
            else
                is_valid_number "$vm_number"
                if [ "$?" -eq 0 ]; then
                    echo "Failed to start cloned vm"
                    main_fn delete "$vm_number"
                fi
            fi

            # start the main
            if [ "$main_running" == "true" ]; then
                main_fn start "$MAIN_VM_NUMBER"
                if [ "$?" -ne 0 ]; then
                     echo "Failed to start main vm"
                fi
            fi

            return $status
            ;;
        "status")
            local vm_number=$2
            local vm_name="${BASE_CLONE_PREFIX}${vm_number}${BASE_CLONE_SUFFIX}"
            local vm_host_ip="${BASE_IP}$(($vm_number+1))"
            local socks_port=$(($vm_number - 1 + $BASE_SOCKS_PORT))

            is_valid_number $vm_number
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                return 1
            fi

            local paused=`is_paused "$vm_number"`
            if [ "$paused" == "true" ]; then
                echo "\"${vm_name}\": [PAUSED]"
                return 0
            fi

            local running=`is_running "$vm_number"`
            if [ "$running" == "true" ]; then
                issocksactive $vm_number
                if [ "$?" -eq 0 ]; then
                    ip=`getpublicip $vm_number`

                    echo "\"${vm_name}\": [RUNNING] *:${socks_port}:${vm_host_ip} -> $ip"
                    return 0
                else
                    echo "\"${vm_name}\": [RUNNING] (tunnel inactive)"
                    return 2
                fi
            else
                echo "\"${vm_name}\": [NOT RUNNING]"
                return 3
            fi
            ;;
        "status-all")
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
    echo "Usage: $0 (start|pause|resume|stop|status|delete) [vm_number]"
    echo "       $0 (connect|check-ip|start-proxy|stop-proxy) [vm_number]"
    echo "       $0 (deploy|status-all|start-all|stop-all|pause-all|resume-all)"
    exit 1
}

function get_next_number {
    LAST=`$VBOXMANAGE list vms | grep -o "$SEARCH_REGEXP" | grep -o "[0-9]*" | sort -n | tail -n 1`
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
    local vm_numbers=`$VBOXMANAGE list vms | grep -o "$SEARCH_REGEXP" | grep -o "[0-9]*" | sort -n`
    echo $vm_numbers
}

# usage: is_running vm_number
# returns 0 if vm running, 1 otherwise
function is_running()
{
    local vm_number=$1
    local vm_name="${BASE_CLONE_PREFIX}${vm_number}${BASE_CLONE_SUFFIX}"
    output=`$VBOXMANAGE list runningvms | grep -oF "$vm_name"`
    if [ "$output" == "$vm_name" ]; then
        echo "true"
        return 0
    else
        echo "false"
        return 1
    fi
}

# usage: is_paused vm_number
# returns 0 if vm paused, 1 otherwise
function is_paused {
    local vm_number=$1
    local vm_name="${BASE_CLONE_PREFIX}${vm_number}${BASE_CLONE_SUFFIX}"

    output=`$VBOXMANAGE showvminfo "$vm_name" | grep 'State:' | sed s'/ //'g | cut -d':' -f2 | cut -d'(' -f1`
    if [ "$output" == "paused" ]; then
        echo "true"
        return 0
    else
        echo "false"
        return 1
    fi
}

# usage: startvm vm_number
function startvm()
{
    local vm_number=$1
    local vm_name="${BASE_CLONE_PREFIX}${vm_number}${BASE_CLONE_SUFFIX}"

    local running=`is_running "$vm_number"`
    if [ "$running" == "true" ]; then
       return 0;
    fi
    echo "Starting vm ${vm_name}..."
    $VBOXMANAGE startvm "$vm_name" --type headless
    return $?
}

# usage: getpublicip vm_number
function getpublicip()
{
    local vm_number=$1
    local vm_host_ip="${BASE_IP}$(($vm_number+1))"

    local running=`is_running "$vm_number"`
    if [ "$running" == "false" ]; then
       return 1;
    fi
    $SSH ${SCRIPT_USER}@${vm_host_ip} curl http://ifconfig.me/ip 2>/dev/null
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
        mkdir -p $SOCKS_PID_DIR
        chown ${SCRIPT_USER}:${SCRIPT_USER} $SOCKS_PID_DIR
    fi

    echo "Starting socks tunnel on port ${socks_port} through ${vm_host_ip}..."
    $DAEMON -F ${SOCKS_PID_DIR}/${socks_service}.pid -n ${socks_service} -- \
            $SSH -D "*:${socks_port}" -q -C -N ${SCRIPT_USER}@${vm_host_ip}

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
        mkdir -p $SOCKS_PID_DIR
        chown ${SCRIPT_USER}:${SCRIPT_USER} $SOCKS_PID_DIR
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
        mkdir -p $SOCKS_PID_DIR
        chown ${SCRIPT_USER}:${SCRIPT_USER} $SOCKS_PID_DIR
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
    $VBOXMANAGE unregistervm "$1" --delete
    return $?
}

# usage: clonevm to_clone clone_name
function clonevm()
{
    echo "Cloning vm ${1}..."
    $VBOXMANAGE clonevm "$1" --groups $GROUP_NAME \
       --mode machine --name "$2" --options link \
       --register --snapshot $MAIN_SNAPSHOT
    return $?
}

function resumevm()
{
    echo "Resuming vm ${1}..."
    $VBOXMANAGE controlvm "$1" resume
    return $?
}

function pausevm()
{
    echo "Pausing vm ${1}..."
    $VBOXMANAGE controlvm "$1" pause
    return $?
}

function hardresetvm()
{
    echo "Resetting vm ${1}..."
    $VBOXMANAGE controlvm "$1" reset
    return $?
}

# usage: poweroffvm vm_name
function poweroffvm()
{
    local vm_name=$1
    echo "Powering off vm ${vm_name}..."
    $VBOXMANAGE controlvm "$vm_name" poweroff
    return $?
}

# usage: acpipoweroffvm vm_number
function acpipoweroffvm()
{
    local vm_number=$1
    local vm_host_ip=$2

    if [ -z "$vm_host_ip" ]; then
        vm_host_ip="${BASE_IP}$(($vm_number+1))"
    fi

    $SSH root@${vm_host_ip} "init 0"
    return $?
}

# usage: waitonip vm_ip
function waitonip()
{
    local vm_ip=$1
    local status=1
    local start=`date +%s`
    while [ "$status" -ne 0 ]; do
        $SSH ${SCRIPT_USER}@${1} "echo VM on host-ip $vm_ip is now up." 2>/dev/null
        status=$?

        local now=`date +%s`
        local runtime=$((now-start))
        if [ "$runtime" -gt $MAX_POWERON_WAIT ]; then
            return 1
        fi
    done
    return 0
}

# usage: waitpoweroffvm vm_number [vm_ip]
function waitpoweroff()
{
    local vm_number=$1
    local vm_ip=$2
    local vm_name="${BASE_CLONE_PREFIX}${vm_number}${BASE_CLONE_SUFFIX}"

    local running=`is_running "$vm_number"`
    if [ "$running" == "false" ]; then
       return 0;
    fi

    echo "Attempting to shut down vm ${vm_name}..."
    acpipoweroffvm "$vm_number" "$vm_ip"

    local start=`date +%s`
    local runtime=0
    while [ "$runtime" -lt "$MAX_POWEROFF_WAIT" ]; do
        running=`is_running "$vm_number"`
        if [ "$running" == "false" ]; then
            echo "Successfully shut down vm ${vm_name}."
            return 0;
        fi

        sleep 2
        now=`date +%s`
        runtime=$((now-start))
    done

    echo "Failed acpi shutdown, attempting hard poweroff..."
    poweroffvm "$vm_name"
    return $?
}

#usage: copy_script output_path
function copy_script()
{
    local script_path=`$REALPATH -e $0`
    local script_name=`basename $0`

    if [ -z "$1" ] || [ -z "$script_path" ]; then
        return 1
    fi

    local output_name=$1
    if [ -d "$output_name" ]; then
        output_name=${output_name}/${script_name}
    fi

    if [ "$script_path" != "`$REALPATH $output_name`" ]; then
        cp $script_path $output_name
    fi

    chmod +x $output_name
    echo $output_name
    return 0
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
