# chromiumos-overlay-saneyan

The Chromium OS overlay for saneyan dev environment.<br>

 * Supports KVM
 * Bundles dev packages and iwlwifi driver

![chromiumos](/chromiumos.png)


## Installation

**Before installing this overlay, you must prepare to build Chromium OS and get the source code.**

Place the overlay into `~/chromiumos/src/overlays`. Then, the dir name must be `overlay-saneyan`.

```
git clone https://github.com/Saneyan/chromiumos-overlay-saneyan.git overlay-saneyan
mv overlay-saneyan ~/chromiumos/src/overlays
```

Create and check out a new branch in each of portage-stable and chromiumos-overlay repository.

```
cd ~/chromiumos/src/third_party/portage-stable
repo start saneyan/master .
cd ../chromiumos-overlay
repo start saneyan/master .
```

#### Edit eclass and ebuild

Add `saneyan` to $ALL\_BOARDS list in `~/chromiumos/src/third_party/chromiumos-overlay/eclass/cros-board.eclass` so that cros can setup and bulid an image for the board.

**Make sure the revision number of the ebuild has been incremented.**

#### Licensing

The `app-shells/zsh-completions` uses BSD license but not BSD-Google. So you must copy the copyright attribution to `~/chromiumos/src/third_party/chromiumos-overlay/licences/copyright-attribution` from the overlay.

```
cp -r ../../overlays/overlay-saneyan/licenses/copyright-attribution/app-shells ./licenses/copyright-attribution
```

#### Fix crosutils (udev)

You should fix mtools to avoid mcopy's flock failure for build\_image.

```
repo download --cherry-pick chromiumos/platform/crosutils 303962/1
```

#### USE flag

 * `kvm`: Enable KVM and install qemu package (containing qemu-system-x86\_64 command, disabling USB passthrough).
 * `neovim`: Install Neovim that's a refactor in the tradition of Vim (accepting ~amd64 keyword). Do not forget Portage must support EAPI 6, or the LPeg which Neovim depends is never installed.

## Build

Enter chroot with cros\_sdk.

```
cros_sdk
```

This command needs to run once.

```
./setup_board --board=saneyan
```

You need to build packages before building an image.

```
./build_packages --board=saneyan
```

After that, let's build an image and copy onto a USB drive.

```
./build_image --board=saneyan --noenable_rootfs_verification --boot_args="noinitrd lsm.module_locking=0 disablevmx=off" dev
cros flash usb:///dev/sdx saneyan/latest
```

## Setup

After staring up, add the kvm\_intel module to Linux kernel and check installation with lsmod.

```
sudo modprobe kvm_intel
lsmod | grep kvm_intel # You will see it.
```

#### Prepare Virtual Machine (Alpine)

Download Alpine Linux ISO and setup disk image and virtual machine. Note that Alpine Linux should be built with vanilla kernel so that Docker can store new images.

```
sudo mkdir -p /usr/local/q/alpine
sudo chown chronos:chronos /usr/local/q/alpine
cd /usr/local/q/alpine
wget http://wiki.alpinelinux.org/cgi-bin/dl.cgi/v3.3/releases/x86_64/alpine-vanilla-3.3.3-x86_64.iso
qemu-img create -f qcow2 alpine.img 20G
qemu-system-x86_64 -daemonize -enable-kvm -m 2048M -drive index=0,media=disk,if=virtio,file=alpine.img -netdev type=user,id=alpnet -device virtio-net-pci,netdev=alpnet -m 2048M -localtime
```

You can connect to the virtual machine with VNC Viewer for Google Chrome or SSH.

#### Remapping Keys

Open chrome://settings-frame/keyboard-overlay and run this snippet to enable to remap CapsLock key to another key.

```js
document.querySelector('#caps-lock-remapping-section').hidden = false;
```

## Update kernel.config

When the target kernel version is `4.4`:

```
cros_workon start --board=saneyan sys-kernel/chromeos-kernel-4_4
cd ~/trunk/src/third_party/kernel/v4.4
# Use kernelconfig to customize your kernel configs.
./chromeos/scripts/kernelconfig editconfig
./chromeos/scripts/prepareconfig chromiumos-x86_64
cp .config ~/trunk/src/overlays/overlay-saneyan/kernel.config
```

If you already execute setup_board, re-execute the command with --force option.

```
./setup_board --board=saneyan --force
```
