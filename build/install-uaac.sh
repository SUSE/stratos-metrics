#!/bin/bash

SLES=$(cat /etc/os-release | grep SLES)
IS_SLES=$?

cat /etc/os-release
echo ""
echo "SLES? : ${IS_SLES}"

# Fail if anything fails to install
set -ex

zypper in -y ruby2.3 ruby2.3-devel gcc-c++ jq curl

if [ $IS_SLES = 1 ]; then
    zypper in -y --type pattern devel_basis
else
    zypper in -y ruby2.3-devel
fi

cp /usr/bin/ruby.ruby2.3 /usr/bin/ruby
ruby --version

echo "Installing UAA Client ..."
gem install cf-uaac

ln -s /usr/bin/uaac.ruby2.3 /usr/bin/uaac
uaac version

if [ $IS_SLES = 1 ]; then
    zypper remove -y --type pattern devel_basis
fi