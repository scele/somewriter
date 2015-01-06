somewriter
==========
[![Build Status](https://travis-ci.org/scele/somewriter.svg)](https://travis-ci.org/scele/somewriter)

Set up Raspberry Pi:
--------------------

```
# Set up WLAN:
# http://www.raspberrypi.org/documentation/configuration/wireless/wireless-cli.md

sudo apt-get install vim

ssh-keygen -t rsa
vim ~/.ssh/authorized_keys

wget http://node-arm.herokuapp.com/node_latest_armhf.deb
sudo dpkg -i node_latest_armhf.deb

sudo npm install -g grunt-cli

git clone https://github.com/scele/somewriter.git

cd somewriter
npm install
grunt
```
