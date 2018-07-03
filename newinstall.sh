#!/usr/bin/env sh

# SYNOPSIS: script to check for requirements

# rsync| curl | wget

agent=`which rsync`
if [ $? -eq 0 ]; then
    echo going to use rsync
else
    agent=`whick curl`
    if [ $? eq 0 ]; then
        echo going to use curl
    else
        agent=`which wget`
        if [ $? eq 0 ]; then
            echo going to use wget
        else
            echo "no agent rsync, curl or wget found to transfer data"
            exit 1
        fi
    fi
fi

lsof=`which lsof`
if [ $? -eq 0 ]; then
    echo lsof = $lsof
else
    echo no lsof found
fi
