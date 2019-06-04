#!/bin/bash

SLES=$(cat /etc/os-release | grep "SLES" -c)
IS_SLES="false"
if [ $SLES -eq 1 ]; then
  IS_SLES="true"
fi

cat /etc/os-release
echo ""
echo "SLES? : ${IS_SLES}"

# Fail if anything fails to install
set -e

ruby --version

set -x
echo "Installing UAA Client ..."
gem install cf-uaac
