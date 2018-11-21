KVMC_PATH=/home/chronos/user/kvmc
IMAGE_PATH=/home/chronos/user/kvmc/debian.img
SHARED_PATH=/home/chronos/user/Downloads/kvmc

cmd_kvmc() {
  local cmd=$1; shift

  case $cmd in
    "init")
      if [ $# -ne 1 ]; then
        echo "Missing vm name."
        return 1
      fi

      local vm_name=$1; shift
      local working=$KVMC_PATH/$vm_name

      mkdir -pv $working
      local storage=$working/storage.qcow2

      if [ ! -e $storage ]; then
        echo "Creating this storage..."
        qemu-img create -f qcow2 $storage 60G
      fi

      echo "Starting virtual machine..."
      touch $working/$vm_name.pid

      sudo qemu-system-x86_64 -daemonize -enable-kvm \
        -m 4096M \
        -netdev type=user,id=alpnet,hostfwd=tcp::2022-:22 \
        -drive index=0,media=disk,if=virtio,file=$storage \
        -device virtio-net-pci,netdev=alpnet \
        -rtc base=localtime \
        -pidfile $working/$vm_name.pid \
        -cdrom $IMAGE_PATH

      echo "Done!"
      ;;

    "start")
      if [ $# -ne 1 ]; then
        echo "Missing vm name."
        return 1
      fi

      local vm_name=$1; shift
      local working=$KVMC_PATH/$vm_name
      local storage=$working/storage.qcow2

      if [ ! -d $working ]; then
        echo "No virtual machine found."
        return 1
      fi

      if [ -e $working/$vm_name.pid ]; then
        echo "This virtual machine is already running."
        return 1
      fi

      echo "Starting virtual machine..."
      mkdir -p $SHARED_PATH/$vm_name
      touch $working/$vm_name.pid

      sudo qemu-system-x86_64 -daemonize -enable-kvm \
        -m 4096M \
        -drive index=0,media=disk,if=virtio,file=$IMAGE_PATH \
        -netdev type=user,id=alpnet,hostfwd=tcp::2022-:22 \
        -device virtio-net-pci,netdev=alpnet \
        -fsdev local,security_model=passthrough,id=fsdev0,path=$SHARED_PATH/$vm_name \
        -device virtio-9p-pci,id=fs0,fsdev=fsdev0,mount_tag=shared_dev \
        -rtc base=localtime \
        -pidfile $working/$vm_name.pid \
 
      echo "Started!"

      cmd_vmc share termina kvmc/$vm_name
      vsh --owner_id=$CROS_USER_ID_HASH --vm_name=termina -- \
        LXD_DIR=/mnt/stateful/lxd \
        LXD_CONF=/mnt/stateful/lxd_conf \
        lxc config device add penguin ${vm_name}-shared disk source="/mnt/shared/Downloads/kvmc/$vm_name" path="/mnt/shared"
      ;;

    "stop")
      if [ $# -ne 1 ]; then
        echo "Missing vm name."
        return 1
      fi

      local vm_name=$1; shift
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

      echo "Stopped!"
      ;;

    "destroy")
      if [ $# -ne 1 ]; then
        echo "Missing vm name."
        return 1
      fi

      local vm_name=$1; shift
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
      ;;

    "exec")
      if [ $# -ne 2 ]; then
        echo "Missing vm name or username."
        return 1
      fi

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
      
      ssh -p 2022 -o NoneSwitch=yes ${username}@127.0.0.1
      ;;

    *) echo "kvmc <command> <vm_name>" ;;
  esac
}
