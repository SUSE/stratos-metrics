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

if [ "$IS_SLES" == "true" ]; then
  echo "Configuring Ruby on SLES"
  gpg --keyserver hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
  zypper in -y jq curl
  curl -sSL https://get.rvm.io | bash
  source /etc/profile.d/rvm.sh
  rvm install 2.3
else
  zypper in -y ruby2.3 ruby2.3-devel gcc-c++ jq curl
  cp /usr/bin/ruby.ruby2.3 /usr/bin/ruby
fi

ruby --version

set -x
echo "Installing UAA Client ..."
gem install cf-uaac

if [ "$IS_SLES" == "false" ]; then
  ln -s /usr/bin/uaac.ruby2.3 /usr/bin/uaac
else
  ln -s ${GEM_HOME}/bin/uaac /usr/bin/uaac
fi

uaac version

# if [ $IS_SLES = 1 ]; then
#     zypper remove -y --type pattern devel_basis
# fi