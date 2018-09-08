#!/usr/bin/env sh

# /*
#  * Copyright (C) Trafikito.com
#  * All rights reserved.
#  *
#  * Redistribution and use in source and binary forms, with or without
#  * modification, are permitted provided that the following conditions
#  * are met:
#  * 1. Redistributions of source code must retain the above copyright
#  *    notice, this list of conditions and the following disclaimer.
#  * 2. Redistributions in binary form must reproduce the above copyright
#  *    notice, this list of conditions and the following disclaimer in the
#  *    documentation and/or other materials provided with the distribution.
#  *
#  * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
#  * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#  * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#  * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
#  * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
#  * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
#  * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
#  * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
#  * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
#  * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
#  * SUCH DAMAGE.
#  */

# basedir is $1 to enable this to run from anywhere
if [ $# -ne 1 ]; then
    echo "Usage: $0 <trafikito base dir>" 1>&2
    exit 1
fi
export BASEDIR=$1

# SYNOPSIS: The real trafikito agent
DEBUG=1


# agent version: will be compared as a string
export AGENT_VERSION=14
export AGENT_NEW_VERSION=$AGENT_VERSION  # redefined in fn_set_available_commands

# Trafikito API URLs: these may change with different api versions: do not store in config
URL="https://ap-southeast-1.api.trafikito.com"
export URL_OUTPUT="$URL/v2/agent/output"
export URL_GET_CONFIG="$URL/v2/agent/get"
export URL_DOWNLOAD="$URL/v2/agent/get_agent_file?file="

# for pgp testing TODO
export URL_DOWNLOAD=http://tui.home/trafikito/

# trim logfile to 100 lines
export LOGFILE=$BASEDIR/var/trafikito.log
if [ -f $LOGFILE ]; then
    cp $LOGFILE $LOGFILE.bak
    tail -n 100 $LOGFILE.bak >$LOGFILE
fi

# source config
. $BASEDIR/etc/trafikito.cfg || exit 1

# source available commands
# TODO make this more robust!
. "$BASEDIR/available_commands.sh" || exit 1

# source function to set os facts || exit 1
. $BASEDIR/lib/set_os.sh

###################################################
# functions to handle logs instead of using syslog
###################################################

fn_log() {
    echo "`date +'%x %X'` $*" >>$LOGFILE
}

fn_debug() {
    if [ "$DEBUG" ]; then
        fn_log "DEBUG $*"
    fi
}

##########################################################
# function to define:
#   $CALL_TOKEN
#   $COMMANDS_TO_RUN: commands to execute from Trafikito
#   $AGENT_NEW_VERSION: current_agent_version for dynamic updates
#   $CYCLE_DELAY: seconds to delay this cycle
#   $TIME_INTERVAL: run interval
#   $WIDGETS: , delimited list of widgets to install
# returns:
#   0 success
#   1 error and log error
##########################################################
fn_get_config() {
    data=`curl --request POST --silent \
               --url     "$URL/v2/agent/get_config" \
               --header  "Content-Type: application/json" \
               --data "{ \"serverId\": \"$SERVER_ID\", \"serverApiKey\": \"$API_KEY\" }"
        `
    # check for curl error
    if [ $? -ne 0 ]; then
        fn_log "curl returned curl error code $?: cannot complete run"
        return 1
    fi
    # check for trafikito error
    echo $data | grep -q error
    if [ $? -eq 0 ]; then
        # {"error":{"code":"#6d5jyjytjh","message":"SEND_DATA_ONCE_PER_MINUTE_OR_YOU_WILL_BE_BLOCKED","env":"production"},"data":null}
        error=`echo $data | sed -e 's/message":"//' -e 's/".*//'`
        fn_log "curl returned Trafikito error '$error': cannot complete run"
        return 1
    fi

    # parse data
    set $data
    CALL_TOKEN=$1
    COMMANDS_TO_RUN=`echo $2 | sed -e 's/,/ /g'`
    AGENT_NEW_VERSION=$3
    CYCLE_DELAY=$4
    TIME_INTERVAL=$5
    WIDGETS=`echo $6 | sed -e 's/,/ /g'`
    
    fn_debug "    CALL_TOKEN $CALL_TOKEN"
    fn_debug "    COMMANDS_TO_RUN $COMMANDS_TO_RUN"
    fn_debug "    AGENT_NEW_VERSION $AGENT_NEW_VERSION"
    fn_debug "    CYCLE_DELAY $CYCLE_DELAY"
    fn_debug "    TIME_INTERVAL $TIME_INTERVAL"
    fn_debug "    WIDGETS $WIDGETS"

    return 0
}

##########################
# execute a single command
##########################
fn_execute_trafikito_cmd() {
    # can execute only commands with trafikito_ in it
    cmd="trafikito_$1"
    if [ -z "$cmd" ]; then
        # can not execute empty string
        echo "No command specified for execute_trafikito_cmd. Command: $cmd"
    elif [ $(echo "$cmd" | grep "trafikito_" | sed "s/[^a-zA-Z_]*//g") = "$cmd" ]; then
        # can execute, let's do it. Echo commands delimiter:
        echo "*-*-*-*------------ Trafikito command: $cmd" >> "$TMP_FILE"
        # $cmd is validated. has trafikito_ prefix and is single word with a-Z and _ characters.
        cmd="$(eval echo "\$$cmd")"
        
        # $cmd command is set by user at available_commands.sh
        eval "$cmd >> $TMP_FILE 2>&1"
    else
        # can not execute command without trafikito_ prefix
        echo "Can not execute command without trafikito_ prefix. Command: $cmd"
    fi
}

##################################################
# start of main
##################################################
fn_log "+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-"
fn_log "agent run started"

fn_set_os

# get config from trafikito
fn_get_config
if [ $? -ne 0 ]; then
    fn_log "Skipping this run"
    exit 1
fi

# save CYCLE_DELAY and TIME_INTERVAL for wrapper
#CYCLE_DELAY=2
echo $CYCLE_DELAY   >$BASEDIR/var/cycle_delay
echo $TIME_INTERVAL >$BASEDIR/var/time_interval

# create new tmp file
>$TMP_FILE

# Run commands and send results to tmp file
for cmd in $COMMANDS_TO_RUN
do
    fn_log "Running $cmd"
    fn_execute_trafikito_cmd "$cmd"
    fn_log "  $cmd is done"
done

# collect available commands from available_commands.sh
echo "*-*-*-*------------ Available commands:" >> "$TMP_FILE"
cat "$BASEDIR/available_commands.sh" | grep -v "#" >> "$TMP_FILE"

curl --request POST \
     --url     "$URL/v2/agent/save_output" \
     --form    output=@$TMP_FILE \
     --form    serverId=$SERVER_ID \
     --form    serverApiKey=$API_KEY

fn_debug "DONE!"

# test if need to upgrade/downgrade agent
if [ $AGENT_VERSION != $AGENT_NEW_VERSION ]; then
    fn_log "Changing this agent (version $AGENT_VERSION) to version $AGENT_NEW_VERSION"
    # TODO
    fn_log "  TODO: download lib/*!"
fi
