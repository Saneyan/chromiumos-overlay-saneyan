#
# Constant variables
#
KVMC_PATH=/home/chronos/user/kvmc
IMAGE_URL="https://gensho.ftp.acc.umu.se/debian-cd/current/amd64/iso-cd/debian-9.6.0-amd64-netinst.iso"
IMAGE_PATH=/home/chronos/user/kvmc/debian.img
SHARED_PATH=/home/chronos/user/Downloads/kvmc

typeset -A NETWORK
NETWORK=(
  [dev]='192.168.0.130/24'
  [saneyan]='192.168.0.10/24'
)

#
# Utilities
#
# ifup <tap_name> <address>/<mask>
ifup() {
  local ifname=$1
  local addr=$2
  sudo ip tuntap add $ifname mode tap user `whoami` || return 1
  sudo ip link set $ifname up || return 1
  sleep 0.5
  sudo ip addr add $addr dev $ifname || return 1
  sudo iptables -A FORWARD -i $ifname -o wlan0 -j ACCEPT
}

# ifdown <tap_name> <address>/<mask>
ifdown() {
  local ifname=$1
  local addr=$2
  sudo ip addr del $addr dev $ifname || return 1
  sleep 0.5
  sudo ip tuntap del $ifname mode tap || return 1
}

# q_start <vm_name> [options]
#
# Options:
# -c <iso_file>   : ISO file path
# -n <tap_name>   : TAP name
# -f              : Directory to share with guest VM
# -p              : Enable Spice
q_start() {
  local vm_name=$1; shift
  local working=$KVMC_PATH/$vm_name
  local args="-daemonize \
              -enable-kvm \
              -m 4096M \
              -smp $(nproc) \
              -cpu host \
              -rtc base=localtime \
              -pidfile $working/$vm_name.pid \
              -drive index=0,media=disk,if=virtio,file=$working/storage.qcow2"

  while getopts "c:n:f:p" opt; do
    case $opt in
      f) args="$args \
               -fsdev local,security_model=passthrough,id=fsdev0,path=$SHARED_PATH/$vm_name \
               -device virtio-9p-pci,id=fs0,fsdev=fsdev0,mount_tag=shared_dev"
        ;;
      p) args="$args \
               -vga qxl \
               -spice port=5900,addr=127.0.0.1,disable-ticketing \
               -device virtio-serial-pci \
               -device virtserialport,chardev=spicechannel0,name=com.gfunction.spice.0 \
               -chardev spicevmc,id=spicechannel0,name=vdagent"
        ;;
      n) local ifname=$OPTARG
         args="$args \
               -netdev tap,id=$ifname,ifname=$ifname,script=no \
               -device virtio-net-pci,netdev=$ifname"
        ;;
      c) args="$args -cdrom $OPTARG"
        ;;
    esac
  done

  touch $working/$vm_name.pid

  sudo qemu-system-x86_64 $args

  if [ $? -ne 0 ]; then
    sudo rm $working/$vm_name.pid
    return 1
  fi

  return 0
}

#
# Subcommands
#
# vm_init <vm_name>
vm_init() {
  local vm_name=$1; shift
  local working=$KVMC_PATH/$vm_name

  if [ -e $working/$vm_name.pid ]; then
    echo "This virtual machine is already running."
    return 1
  fi
 
  mkdir -p $KVMC_PATH

  if [ ! -e $IMAGE_PATH ]; then
    echo "Downloading Debian image..."
    curl $IMAGE_URL > $IMAGE_PATH

    if [ $? -ne 0 ]; then
      echo "Failed to download Debian image."
      return 1
    fi
  fi

  mkdir -pv $working
  local storage=$working/storage.qcow2

  if [ ! -e $storage ]; then
    echo "Creating storage..."
    qemu-img create -f qcow2 $storage 60G

    if [ $? -ne 0 ]; then
      echo "Failed to create storage."
      return 1
    fi
  fi

  local ifname="tap-$vm_name"
  local addr=NETWORK[$vm_name]

  ifup $ifname $addr || (echo 'Cannot up network interface.'; return 1)

  echo "Starting virtual machine..."

  q_start $vm_name -f -n $ifname -c $IMAGE_PATH

  if [ $? -ne 0 ]; then
    echo "Cannot start virtual machine."
    ifdown $ifname $addr || (echo "Cannot down network inteface."; return 1)
    return 1
  fi
 
  echo "Started!"
}

# vm_start <vm_name>
vm_start() {
  local vm_name=$1
  local working=$KVMC_PATH/$vm_name

  if [ ! -d $working ]; then
    echo "No virtual machine found."
    return 1
  fi

  if [ -e $working/$vm_name.pid ]; then
    echo "This virtual machine is already running."
    return 1
  fi

  local ifname="tap-$vm_name"
  local addr=NETWORK[$vm_name]

  ifup $ifname $addr || (echo 'Cannot up network interface.'; return 1)

  echo "Starting virtual machine..."

  q_start $vm_name -f -n $ifname

  if [ $? -ne 0 ]; then
    echo "Cannot start virtual machine."
    ifdown $ifname $addr || (echo "Cannot down network inteface."; return 1)
    return 1
  fi
 
  echo "Started!"

  concierge_client --start_termina_vm \
    --name=termina \
    --cryptohome_id="${CROS_USER_ID_HASH}" 

  if [ $? -ne 0 ]; then
    echo "Cannot start termina vm. Skipped sharing folder."
    return 1
  fi

  share $vm_name
}

# vm_stop <vm_name>
vm_stop() {
  local vm_name=$1
  local working=$KVMC_PATH/$vm_name

  if [ ! -d $working ]; then
    echo "No virtual machine found."
    return 1
  fi

  if [ ! -e $working/$vm_name.pid ]; then
    echo "This virtual machine has been stopped."
    return 1
  fi

  echo "Stopping virtual machine..."
  sudo kill $(cat $working/$vm_name.pid)
  sudo rm $working/$vm_name.pid

  local ifname="tap-$vm_name"

  ifdown $ifname || (echo "Cannot down network inteface."; return 1)

  echo "Stopped!"
}

# vm_destroy <vm_name>
vm_destroy() {
  local vm_name=$1
  local working=$KVMC_PATH/$vm_name

  if [ ! -d $working ]; then
    echo "No virtual machine found."
    return 1
  fi

  if [ -e $working/$vm_name.pid ]; then
    echo "Cannot destroy this virtual machine because it's still running."
    return 1
  fi

  sudo rm -rf $working

  echo "Done!"
}

# vm_exec <vm_name> <username>
vm_exec() {
  local vm_name=$1; shift
  local working=$KVMC_PATH/$vm_name

  if [ ! -d $working ]; then
    echo "No virtual machine found."
    return 1
  fi

  if [ ! -e $working/$vm_name.pid ]; then
    echo "This virtual machine is not running."
    return 1
  fi

  local username=$1; shift
      
  ssh -o NoneSwitch=yes ${username}@${NETWORK[$vm_name]}
}

# vm_share <vm_name>
vm_share() {
  local vm_name=$1
  cmd_vmc share termina kvmc/$vm_name

  echo "Waiting for termina mounting shared folder..."
  sleep 3

  vsh --owner_id=$CROS_USER_ID_HASH --vm_name=termina -- \
    LXD_DIR=/mnt/stateful/lxd \
    LXD_CONF=/mnt/stateful/lxd_conf \
    lxc config device add penguin ${vm_name}-shared disk source="/mnt/shared/Downloads/kvmc/$vm_name" path="/mnt/shared"
}


cmd_kvmc() {
  local cmd=$1; shift

  case $cmd in
    "init")
      if [ $# -ne 1 ]; then
        echo "Missing vm name."
        return 1
      fi

      vm_init $1
      ;;

    "start")
      if [ $# -ne 1 ]; then
        echo "Missing vm name."
        return 1
      fi

      vm_start $1
      ;;

    "stop")
      if [ $# -ne 1 ]; then
        echo "Missing vm name."
        return 1
      fi

      vm_stop $1
      ;;

    "destroy")
      if [ $# -ne 1 ]; then
        echo "Missing vm name."
        return 1
      fi

      vm_destroy $1
      ;;

    "exec")
      if [ $# -ne 2 ]; then
        echo "Missing vm name or username."
        return 1
      fi

      vm_exec $1 $2
      ;;

    "share")
      if [ $# -ne 1 ]; then
        echo "Missing vm name."
        return 1
      fi

      vm_share $1
      ;;

    *) cat << EOF
Usage: kvmc <command> [options]
Commands:
  init <vm_name>             Create VM
  start <vm_name>            Start VM
  stop <vm_name>             Stop VM
  destroy <vm_name>          Destroy VM
  exec <vm_name> <username>  Enter inside VM
  share <vm_name>            Share folder with VM
EOF
      ;;
  esac
}
