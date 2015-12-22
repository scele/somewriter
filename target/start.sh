#!/bin/bash

# Invoke this script from /etc/rc.local

cd `dirname $0`
sudo -u pi forever start out/main.js
