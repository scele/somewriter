#!/usr/bin/env bash

. ~/.nvm/nvm.sh
nvm use 6
forever start out/server/server.js
