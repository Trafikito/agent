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

# SYNOPSIS: The real trafikito agent
DEBUG=1

export BASEDIR=`echo $0 | sed -e 's#/lib/.*##'`

# agent version: will be compared as a string
export AGENT_VERSION=15
export AGENT_NEW_VERSION=$AGENT_VERSION  # redefined in fn_get_available_commands

# Trafikito API URLs: these may change with different agent versions: do not store in config
export URL_OUTPUT="https://api.trafikito.com/v1/agent/output"
export URL_GET_CONFIG="https://api.trafikito.com/v1/agent/get"
export URL_DOWNLOAD=${URL_DOWNLOAD:-"https://api.trafikito.com/v1/agent/get_agent_file?file="}  # override from environment for testing

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
    test -z "DEBUG" || echo "`date +'%x %X'` $*"
}

fn_debug() {
    if [ "$DEBUG" ]; then
        fn_log "DEBUG $*"
    fi
}

##########################################################
# function to get:
#   $COMMANDS_TO_RUN: commands to execute from Trafikito
#   $AGENT_NEW_VERSION: current_agent_version for dynamic updates
#   $CYCLE_DELAY: seconds to delay this cycle
#   $CALL_TOKEN: version 1
##########################################################
fn_set_commands_to_run() {
    data=`curl -s -X POST -H "Authorization: $API_KEY" \
         --data "serverId=$SERVER_ID&agentVersion=$AGENT_VERSION&os=$os&osCodename=$os_codename&osRelease=$os_release&centosFlavor=$centos_flavor" \
         "$URL_GET_CONFIG" --retry 3 --retry-delay 1 --max-time 30`
    fn_debug "DATA = $data"
    echo $URL_OUTPUT | grep -q "v2"
    if [ $? ]; then
        fn_debug "use v1 format"
        COMMANDS_TO_RUN=`echo $data | sed -e 's#^[^,]*##' -e 's/,/ /g'`
        CALL_TOKEN=`echo $data | sed -e 's#,.*##'`
        AGENT_NEW_VERSION=14
        CYCLE_DELAY=0
    else
        fn_debug "use v2 format"
        set $data
        COMMANDS_TO_RUN=$1
        CALL_TOKEN='N/A'
        AGENT_NEW_VERSION=$2
        CYCLE_DELAY=$3
    fi
    
    fn_debug "    COMMANDS_TO_RUN $COMMANDS_TO_RUN"
    fn_debug "    CALL_TOKEN $CALL_TOKEN"
    fn_debug "    AGENT_NEW_VERSION $AGENT_NEW_VERSION"
    fn_debug "    CYCLE_DELAY $CYCLE_DELAY"

    # save CYCLE_DELAY for wrapper
    #CYCLE_DELAY=2
    echo $CYCLE_DELAY >$BASEDIR/var/cycle_delay

    tmp=`echo $COMMANDS_TO_RUN | grep '{"data":null,"error":{"code":"#q2w4544h4asa2gAefg53GHrfd","message":'`
    if [ -n "$tmp" ]; then
        ERROR="Error: Do not call more then once per minute. ANOTHER_REQUEST_IN_PROGRESS"
        return 1
    fi

    tmp=`echo "$COMMANDS_TO_RUN" | grep "\"error\":{\"code\":\"#"`
    if [ -n "$tmp" ]; then
        ERROR="Error: Can not get commands to run: $tmp"
        return 1
    fi
        
    if [ -z "$COMMANDS_TO_RUN" ];
    then
        ERROR="Error: received empty config from Trafikito.com. Probably a network outage?"
        return 1
    fi
    
    ERROR=""
    return 0
}

###########################################
# execute all commands received from server
###########################################
fn_execute_all_commands() {
    fn_debug "COMMANDS_TO_RUN: $COMMANDS_TO_RUN"

    for cmd in $COMMANDS_TO_RUN
    do
        fn_log "Running $cmd"
        fn_execute_trafikito_cmd "$cmd"
        fn_log "Running $cmd is done"
    done
}

##########################
# execute a single command
##########################
fn_execute_trafikito_cmd() {
    # can execute only commands with trafikito_ in it
    cmd="$1"
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

# get from trafikito:
#   commands to run from trafikito
fn_set_commands_to_run

if [ ! -z "$ERROR" ]; then
    fn_log $ERROR
    fn_log "Skipping this run"
else
    # create new tmp file
    >$TMP_FILE

    # Run commands and send results to tmp file
    fn_execute_all_commands

    # collect available commands from available_commands.sh
    echo "*-*-*-*------------ Available commands:" >> "$TMP_FILE"
    cat "$BASEDIR/available_commands.sh" | grep -v "#" >> "$TMP_FILE"

    # test url version in use
    echo $URL_OUTPUT | grep -q "v2"
    if [ $? ]; then
        fn_debug "use v1 url to send data to Trafikito"
        curl -s -X POST -H "Authorization: $API_KEY" -H "Content-Type: multipart/form-data" -F "output=@$TMP_FILE" "$URL_OUTPUT?callToken=$CALL_TOKEN" \
             --retry 3 --retry-delay 1 --max-time 30 > /dev/null 2>&1
    else
        fn_debug "use v2 url to send data to Trafikito"
        curl -s -X POST -H "Authorization: $API_KEY" --data "serverId=$SERVER_ID" \
             -H "Content-Type: multipart/form-data" \
             -F "output=@$TMP_FILE" "$URL_OUTPUT" --retry 3 --retry-delay 1 --max-time 30
    fi
    fn_debug "DONE!"

    # test if need to upgrade/downgrade agent
    if [ $AGENT_VERSION != $AGENT_NEW_VERSION ]; then
        fn_log "Changing this agent (version $AGENT_VERSION) to version $AGENT_NEW_VERSION"
        # TODO
        fn_log "  TODO: download lib/*!"
    fi
fi
