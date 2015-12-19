somewriter
==========
[![Build Status](https://travis-ci.org/scele/somewriter.svg)](https://travis-ci.org/scele/somewriter)
[![Coverage Status](https://coveralls.io/repos/scele/somewriter/badge.svg?branch=master)](https://coveralls.io/r/scele/somewriter?branch=master)

Set up Raspberry Pi:
--------------------

```
# Set up WLAN:
# http://www.raspberrypi.org/documentation/configuration/wireless/wireless-cli.md

# Disable WLAN dongle power management to avoid dropped packets:
sudo bash -c 'echo "options 8192cu rtw_power_mgnt=0 rtw_enusbss=0" > /etc/modprobe.d/8192cu.conf'

sudo apt-get install vim

ssh-keygen -t rsa
vim ~/.ssh/authorized_keys

wget http://node-arm.herokuapp.com/node_latest_armhf.deb
sudo dpkg -i node_latest_armhf.deb

sudo npm install -g grunt-cli

git clone https://github.com/scele/somewriter.git

cd somewriter
sudo apt-get install libudev-dev
npm install
grunt
```
