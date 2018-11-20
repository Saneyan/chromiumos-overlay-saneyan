# chromiumos-overlay-saneyan

**This build is based on Chromium OS release-R71-11151.B**

The Chromium OS overlay for saneyan dev environment.<br>

 * KVM support
 * Iwlwifi support
 * QEMU with KVM, VirtFS and Spice support
 * Plan 9 resource sharing support
 
## Tested devices

 * Thinkpad T480
 * Thinkpad X230

## Channels

 * [Release (R71)](https://github.com/Saneyan/chromiumos-overlay-saneyan/releases/tag/r71) - Based on tag release-R71-11151.B in.
 * [Edge (R72)](https://github.com/Saneyan/chromiumos-overlay-saneyan/tree/r72) - Based on master branch. Unstable.

## Installation
```
(outside) mkdir -p ~/chromiumos
(outside) repo init -u https://chromium.googlesource.com/chromiumos/manifest.git --repo-url https://chromium.googlesource.com/external/repo.git -b release-R71-11151.B
(outside) repo sync -j8
```

Place the overlay into `~/chromiumos/src/overlays`. Make sure the directory name of overlay is `overlay-saneyan`.

```
(outside) git clone https://github.com/Saneyan/chromiumos-overlay-saneyan.git overlay-saneyan
mv overlay-saneyan ~/chromiumos/src/overlays
```

#### Edit eclass and ebuild

Add `saneyan` to $ALL\_BOARDS list in `~/chromiumos/src/third_party/chromiumos-overlay/eclass/cros-board.eclass` so cros can setup and bulid an image for this board.

#### Licensing

`sys-firmware/edk2-ovmf` uses BSD license but not BSD-Google. So you must copy the copyright attribution to `~/chromiumos/src/third_party/chromiumos-overlay/licences/copyright-attribution` from the overlay.

#### USE flag

 * `kvm`: Enable KVM and install qemu package (containing qemu-system-x86\_64 command, disabling USB passthrough).

## Build

1. Enter chroot with cros\_sdk.

```
(outside) cros_sdk
```

2. This command needs to run once.

```
(inside) ./setup_board --board=saneyan
```

3. Copy `package.env` and the environment config file to `/build/saneyan/etc/portage`.

4. You need to build packages before building an image.

```
(inside) ./build_packages --board=saneyan
```

5. Let's build an image and copy onto a USB drive.

```
(inside) ./build_image --board=saneyan --noenable_rootfs_verification --boot_args="noinitrd lsm.module_locking=0 disablevmx=off" dev
(inside) cros flash usb:///dev/sdx saneyan/latest
```

## Setup

#### API Keys

```
(device) sudo mount -o remount,rw /
```

```
# /etc/chrome_dev.conf
GOOGLE_API_KEY=your_api_key
GOOGLE_DEFAULT_CLIENT_ID=your_client_id
GOOGLE_DEFAULT_CLIENT_SECRET=your_client_secret
```

Reboot your system to apply API keys.

#### Add IME Engine to Crostini

```
(penguin) sudo apt install fcitx fcitx-mozc
```

```
# /etc/systemd/user/cros-garcon.service.d/cros-garcon-override.conf
Environment="XMODIFIERS=@im=fcitx"
Environment="GTK_IM_MODULE=fcitx"
Environment="QT_IM_MODULE=fcitx"
```

```
(penguin) fcitx-autostart
```

#### Install Japanese Font

Japanese characters could be text garbling on Linux Apps. Installing Japanese font like IPA font solves this issue.

```
(penguin) sudo apt install fonts-ipafont
```

#### LXC inside Crostini

##### Preparation (for Debian)

```
(crosh) vmc start termina
```

```
(termina) lxc launch images:debian/9 my-container
```

```
(termina) lxc storage volume create default shared-volume
```

```
(termina) lxc storage volume attach default shared-volume my-container data /data
(termina) lxc storage volume attach default shared-volume penguin data /data
```

#### Virtual Machine with QEMU

Add the kvm\_intel module to Linux kernel and check installation with lsmod.

```
(device) sudo modprobe kvm_intel
(device) lsmod | grep kvm_intel # You will see it.
```

##### Preparation (for Alpine)

Download Alpine Linux ISO and setup disk image and virtual machine. Note that Alpine Linux should be built with vanilla kernel so that Docker can store new images.

1. Create QEMU image formatted in qcow2
```
(device) qemu-img create -f qcow2 alpine.img 20G
```

2. Start virtual machine with ISO file to install Alpine Linux.
```
(device) qemu-system-x86_64 -daemonize -enable-kvm -m 2048M -drive index=0,media=disk,if=virtio,file=alpine.img -netdev type=user,id=alpnet -device virtio-net-pci,netdev=alpnet -localtime -cdrom alpine.iso
```

3. Install Alpine Linux and restart virtual machine to boot from the image file.
```
(vm) setup-alpine
(vm) poweroff -f
(device) qemu-system-x86_64 -daemonize -enable-kvm -m 2048M -drive index=0,media=disk,if=virtio,file=alpine.img -netdev type=user,id=alpnet,hostfwd=tcp::22-:22 -device virtio-net-pci,netdev=alpnet -localtime
```
You can connect to this virtual machine with VNC Viewer for Google Chrome or SSH.

##### Optional

This overlay enables QEMU to use VirtFS. It means you can share files between host and guest using 9p virtio as the transport. 

4. Create a directory in home.
```
(device) mkdir ~/hostshare
```

5. Start virtual machine with additional options.
```
(device) qemu-system-x86_64 -daemonize -enable-kvm -m 2048M -drive index=0,media=disk,if=virtio,file=alpine.img -netdev type=user,id=alpnet,hostfwd=tcp::22-:22 -device virtio-net-pci,netdev=alpnet -localtime -fsdev local,security_model=passthrough,id=fsdev0,path=/home/chronos/user/hostshare -device virtio-9p-pci,id=fs0,fsdev=fsdev0,mount_tag=hostshare
```

6. Create a user which UID and GID are same as host's IDs.
```
(vm) adduser saneyan
```

7. Mount the 9p filesystem from the host using 9p virtio.
```
(vm) mkdir /home/saneyan/hostshare
(vm) mount -t 9p -o trans=virtio,version=9p2000.L,rw hostshare /home/saneyan/hostshare
```

Now you can write or read files from either host or guest.

## Update kernel.config

When the target kernel version is `4.14`:

```
(inside) cros_workon --board=saneyan start sys-kernel/chromeos-kernel-4_14
(inside) cd ~/trunk/src/third_party/kernel/v4.14
# Use kernelconfig to customize your kernel configs.
(inside) ./chromeos/scripts/kernelconfig editconfig
(inside) ./chromeos/scripts/prepareconfig chromiumos-x86_64
(inside) cp .config ~/trunk/src/overlays/overlay-saneyan/kernel.config
(inside) cros_workon --board=saneyan stop sys-kernel/chromeos-kernel-4_14
```

If you already execute setup_board, re-execute the command with --force option.

```
(inside) ./setup_board --board=saneyan --force
```

## References
 * [API Keys - The Chromium Projects](https://www.chromium.org/developers/how-tos/api-keys)
 * [9p virtio - KVM](https://www.linux-kvm.org/page/9p_virtio)
 * [Storage management in LXD 2.15](https://blog.ubuntu.com/2017/07/12/storage-management-in-lxd-2-15)
 * [Quick note on Crostini + Chinese IME](https://itsze.ro/blog/2018/08/08/quick-note-on-crostini-chinese-ime.html)
