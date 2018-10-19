#!/bin/bash

echo 'password' | sudo -S usermod -u $LUID user
sudo groupmod -g $LGID user

/bin/bash
