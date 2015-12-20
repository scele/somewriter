#!/bin/bash

# Invoke this script from /etc/rc.local

sudo -u pi forever start `dirname $0`/out/src/main.js
