#!/bin/bash

QEMU_MGR="sudo /usr/sbin/qm"
SSH="/usr/bin/ssh -o ConnectTimeout=1 -o StrictHostKeyChecking=no"
SCP="/usr/bin/scp -o StrictHostKeyChecking=no"
DAEMON="/usr/bin/daemon"
REALPATH="/usr/bin/realpath"

SCRIPT_USER="vincent"

HOSTNAME_PREFIX='debian-vpn-'
MAIN_VM_NUMBER=1

SEARCH_REGEXP="debian\-vpn\-[0-9]*"
CLONE_PREFIX_ID="900"

BASE_IP="192.168.56."
BASE_SOCKS_PORT=1080

SOCKS_PID_DIR="/run/user/$UID/socks/"
SOCKS_DAEMON_PREFIX="socks-"

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
                 echo "Failed to start vm $vm_number"
                 return 1
            fi

            waitonip "$vm_host_ip"
            if [ "$?" -ne 0 ]; then
                echo "Timed out waiting for vm $vm_number to start on ip $vm_host_ip"
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
        "stop-vpn")
            local vm_number=$2

            if [ -z "$vm_number" ]; then
                help
            fi

            is_valid_number $vm_number
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                return 1
            fi

            local running=`is_running "$vm_number"`
            if [ "$running" == "false" ]; then
                echo "VM $vm_number is not running"
                return 1
            fi

	    stopvpn $vm_number
	    return $?
	    ;;
        "start-vpn")
            local vm_number=$2

            if [ -z "$vm_number" ]; then
                help
            fi

            is_valid_number $vm_number
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                return 1
            fi

            local running=`is_running "$vm_number"`
            if [ "$running" == "false" ]; then
                echo "VM $vm_number is not running"
                return 1
            fi

	    startvpn $vm_number
	    return $?
	    ;;
        "restart-vpn")
            local vm_number=$2

            if [ -z "$vm_number" ]; then
                help
            fi

            is_valid_number $vm_number
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                return 1
            fi

            local running=`is_running "$vm_number"`
            if [ "$running" == "false" ]; then
                echo "VM ${vm_number} is not running"
                return 1
            fi

	    restartvpn $vm_number
	    return $?
	    ;;
        "stop")
            local vm_number=$2

            if [ -z "$vm_number" ]; then
                help
            fi

            is_valid_number $vm_number
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                return 1
            fi

#            local paused=`is_paused "$vm_number"`
#            if [ "$paused" == "true" ]; then
#                main_fn resume "$vm_number"
#
#                if [ "$?" -ne 0 ]; then
#                    echo "Failed to resume VM ${vm_number}"
#                fi
#            fi

            waitpoweroff "$vm_number"
            if [ "$?" -ne 0 ]; then
                echo "Failed to shut down vm $vm_number."
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

            deletevm "$vm_number"
            status=$?
            if [ "$status" -ne 0 ]; then
                echo "Failed to delete vm ${vm_number}."
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

            local vm_hostname="${HOSTNAME_PREFIX}$(($vm_number))"
            local vm_host_ip="${BASE_IP}$(($vm_number+1))"
            local vm_vmid="$(($CLONE_PREFIX_ID+$vm_number+1))"

	    main_vmid=`get_vmid $MAIN_VM_NUMBER`
            local MAIN_IP="${BASE_IP}$(($MAIN_VM_NUMBER+1))"

            #main_running=`is_running "$MAIN_VM_NUMBER"`
            #main_fn stop "$MAIN_VM_NUMBER"
            #if [ "$?" -ne 0 ]; then
            #    return 1
            #fi

            $QEMU_MGR clone $main_vmid $vm_vmid --name $vm_hostname
            if [ "$?" -ne 0 ]; then
                echo "Failed to clone vm"
                return 1
            fi

            # wait for vm to be up on the main ip
            startvm "$vm_number"
            if [ "$?" -ne 0 ]; then
                 echo "Failed to start cloned vm"
                 main_fn delete "$vm_number"
                 #main_fn start "$MAIN_VM_NUMBER"
                 return 1
            fi

            waitonip "$MAIN_IP"
            if [ "$?" -ne 0 ]; then
                echo "Timed out waiting for vm"

                waitpoweroff "$vm_number"
                if [ "$?" -eq 0 ]; then
                    main_fn delete "$vm_number"
                else
                    echo "Failed to shut down vm $vm_number."
                fi

                #main_fn start "$MAIN_VM_NUMBER"
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
                waitpoweroff "$vm_number"
                status=$?
            else
                echo "Failed to copy setup script to $vm_number"
                main_fn delete "$vm_number"
            fi

            rm $tempfile

            if [ "$status" -eq 0 ]; then
                main_fn start "$vm_number"
                status=$?
            fi

            if [ "$status" -eq 0 ]; then
                echo "VM ${vm_number} deployed."
            else
                is_valid_number "$vm_number"
                if [ "$?" -eq 0 ]; then
                    echo "Failed to start cloned vm"
                    main_fn delete "$vm_number"
                fi
            fi

            # start the main
            #if [ "$main_running" == "true" ]; then
            #    main_fn start "$MAIN_VM_NUMBER"
            #    if [ "$?" -ne 0 ]; then
            #         echo "Failed to start main vm"
            #    fi
            #fi

            return $status
            ;;
        "status")
            local vm_number=$2
            local vm_host_ip="${BASE_IP}$(($vm_number+1))"
            local socks_port=$(($vm_number - 1 + $BASE_SOCKS_PORT))

            is_valid_number $vm_number
            if [ "$?" -ne 0 ]; then
                echo "No such vm number"
                return 1
            fi

#            local paused=`is_paused "$vm_number"`
#            if [ "$paused" == "true" ]; then
#                echo "\"${vm_name}\": [PAUSED]"
#                return 0
#            fi

            local running=`is_running "$vm_number"`
            if [ "$running" == "true" ]; then
                issocksactive $vm_number
                if [ "$?" -eq 0 ]; then
                    ip=`getpublicip $vm_number`

                    echo "\"${vm_number}\": [RUNNING] *:${socks_port}:${vm_host_ip} -> $ip"
                    return 0
                else
                    echo "\"${vm_number}\": [RUNNING] (tunnel inactive)"
                    return 2
                fi
            else
                echo "\"${vm_number}\": [NOT RUNNING]"
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
    echo "Usage: $0 (start|stop|status|delete) [vm_number]"
    echo "       $0 (connect|check-ip|start-proxy|stop-proxy) [vm_number]"
    echo "       $0 (start-vpn|stop-vpn|restart-vpn) [vm_number]"
    echo "       $0 (deploy|status-all|start-all|stop-all)"
    exit 1
}

function get_next_number {
    p=$(($MAIN_VM_NUMBER-1))
    for i in `get_vm_numbers`; do
        if [ "$i" -ne "$(($p+1))" ]; then
            echo $(($p+1));
            return
            break;
        fi;
    p=$i;
    done;
    echo $(($p+1))
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
    local vm_numbers=`$QEMU_MGR list | grep -o "$SEARCH_REGEXP" | grep -o "[0-9]*" | sort -n`
    echo $vm_numbers
}

# usage: get_vmid vm_number
# returns the vmid
function get_vmid {
    local vm_number=$1
    local vm_name="${HOSTNAME_PREFIX}${vm_number}"
    output=`$QEMU_MGR list | grep "$vm_name" | head -n 1`
    number=`echo $output | cut -d' ' -f 1`
    
    if [ -z "$number" ]; then
	    echo "-1"
	    return -1
    fi

    echo $number
    return $number
}

# usage: is_running vm_number
# returns 0 if vm running, 1 otherwise
function is_running()
{
    local vm_number=$1
    local vm_name="${HOSTNAME_PREFIX}${vm_number}"
    output=`$QEMU_MGR list | grep "$vm_name" | grep -o "running" | head -n 1`
    if [ "$output" == "running" ]; then
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
    local running=`is_running "$vm_number"`
    if [ "$running" == "true" ]; then
       return 0;
    fi

    vmid=`get_vmid $vm_number`

    if [ "$vmid" -lt 0 ]; then
	    echo "No such vm"
	    return -1
    fi

    echo "Starting vm with id $vmid ..."
    $QEMU_MGR start $vmid
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

# usage: stopvpn vm_number
function stopvpn()
{
    local vm_number=$1
    local vm_host_ip="${BASE_IP}$(($vm_number+1))"

    local running=`is_running "$vm_number"`
    if [ "$running" == "false" ]; then
       return 1;
    fi
    $SSH root@${vm_host_ip} /etc/monit/windscribe-wrapper.sh stop
    return $?
}

# usage: startvpn vm_number
function startvpn()
{
    local vm_number=$1
    local vm_host_ip="${BASE_IP}$(($vm_number+1))"

    local running=`is_running "$vm_number"`
    if [ "$running" == "false" ]; then
       return 1;
    fi
    $SSH root@${vm_host_ip} /etc/monit/windscribe-wrapper.sh start
    return $?
}

# usage: restartvpn vm_number
function restartvpn()
{
    local vm_number=$1
    local vm_host_ip="${BASE_IP}$(($vm_number+1))"

    local running=`is_running "$vm_number"`
    if [ "$running" == "false" ]; then
       return 1;
    fi
    $SSH root@${vm_host_ip} /etc/monit/windscribe-wrapper.sh stop 2>/dev/null
    $SSH root@${vm_host_ip} /etc/monit/windscribe-wrapper.sh start
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

#usage deletevm vm_number
function deletevm()
{
    local vm_number=$1
    vmid=`get_vmid $vm_number`

    if [ "$vmid" -lt 0 ]; then
	    echo "No such vm"
	    return -1
    fi

    echo "Deleting vm with id $vmid ..."
    $QEMU_MGR destroy $vmid --purge
    return $?
}

# usage: clonevm clone_number
function clonevm()
{
    local vm_number=$1
    vmid=`get_vmid $vm_number`

    echo "Cloning vm ${1}..."
    $QEMU_MGR clone "$1" --groups $GROUP_NAME \
       --mode machine --name "$2" --options link \
       --register --snapshot $MAIN_SNAPSHOT
    return $?
}

function hardresetvm()
{
    local vm_number=$1
    vmid=`get_vmid $vm_number`

    if [ "$vmid" -lt 0 ]; then
	    echo "No such vm"
	    return -1
    fi

    echo "Resetting vm with id $vmid..."
    $QEMU_MGR reset $vmid
    return $?
}

# usage: poweroffvm vm_number
function poweroffvm()
{
    local vm_number=$1
    vmid=`get_vmid $vm_number`

    if [ "$vmid" -lt 0 ]; then
	    echo "No such vm"
	    return -1
    fi

    echo "Powering off vm with id $vmid..."
    $QEMU_MGR shutdown $vmid --forceStop 1
    return $?
}

# usage: acpipoweroffvm vm_number
function acpipoweroffvm()
{
    local vm_number=$1
    vmid=`get_vmid $vm_number`

    if [ "$vmid" -lt 0 ]; then
	    echo "No such vm"
	    return -1
    fi

    echo "Powering off vm with id $vmid..."
    $QEMU_MGR shutdown $vmid
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

# usage: waitpoweroffvm vm_number
function waitpoweroff()
{
    local vm_number=$1
    local vm_name="${HOSTNAME_PREFIX}${vm_number}"

    local running=`is_running "$vm_number"`
    if [ "$running" == "false" ]; then
       return 0;
    fi

    echo "Attempting to shut down vm ${vm_name}..."
    acpipoweroffvm "$vm_number"

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
    poweroffvm $vm_number
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
allow-hotplug ens18
iface ens18 inet dhcp

allow-hotplug ens19
iface ens19 inet static
    address \${VM_HOST_IP}/24
EOF
DEPLOY_SCRIPT
}

main_fn $1 $2 $3 $4 $5 $6
exit $?
