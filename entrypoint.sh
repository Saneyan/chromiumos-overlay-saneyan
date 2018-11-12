#!/bin/bash

echo 'password' | sudo -S usermod -u $LUID user
sudo groupmod -g $LGID user

mkdir -p ~/chromiumos/src/overlays/overlay-saneyan
sudo mount --bind ~/overlays/overlay-saneyan ~/chromiumos/src/overlays/overlay-saneyan

/bin/bash
