#!/bin/bash

zypper in -y ruby ruby-devel gcc-c++

SLES=$(cat /etc/os-release | grep SLES)
IS_SLES=$?

if [ $IS_SLES = 1 ]; then
    zypper in -y --type pattern devel_basis
else
    zypper in -y ruby-devel
fi

gem install cf-uaac

if [ $IS_SLES = 1 ]; then
    zypper remove -y --type pattern devel_basis
fi