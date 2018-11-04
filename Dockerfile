FROM ubuntu:18.10

ENV TZ=Asia/Tokyo

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y git-core gitk git-gui curl lvm2 thin-provisioning-tools python-pkg-resources python-virtualenv python-oauth2client kmod sudo

RUN sed -i 's/udev_sync = 1/udev_sync = 0/' /etc/lvm/lvm.conf && \
    sed -i 's/udev_rules = 1/udev_rules = 0/' /etc/lvm/lvm.conf

RUN git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git /tmp/depot_tools && \
    cp -rv /tmp/depot_tools/* /usr/local/bin && \
    rm -rf /tmp/depot_tools

RUN useradd -G sudo -m -s /bin/bash user && \
    echo user:password | chpasswd

COPY cros_init /sbin/cros_init
COPY cros_update /sbin/cros_update
COPY entrypoint.sh /sbin/entrypoint.sh

USER user

RUN mkdir /home/user/chromiumos

WORKDIR /home/user/chromiumos

ENTRYPOINT ["/sbin/entrypoint.sh"]
