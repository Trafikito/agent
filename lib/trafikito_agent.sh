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

START=$(date +%s)

# basedir is $1 to enable this to run from anywhere
if [ $# -ne 1 ]; then
    echo "Usage: $0 <trafikito_base_dir>" 1>&2
    exit 1
fi
export BASEDIR=$1

# TODO remove this in production
DEBUG=1


# agent version: will be compared as a string
export AGENT_VERSION=17
export AGENT_NEW_VERSION=$AGENT_VERSION  # redefined in fn_set_available_commands

# Trafikito API URLs: these may change with different api versions: do not store in config
URL="https://ap-southeast-1.api.trafikito.com"

# trim logfile to 1000 lines
export LOGFILE=$BASEDIR/var/trafikito.log
if [ -f $LOGFILE ]; then
    cp $LOGFILE $LOGFILE.bak
    tail -n 1000 $LOGFILE.bak >$LOGFILE
fi

LAST_CONFIG=$BASEDIR/var/last_config.tmp

# source config
. $BASEDIR/etc/trafikito.cfg || exit 1

# regexps for available_commands.sh checking
                                RegexpCommand='^trafikito_[a-zA-Z0-9_]+="[^"]+"[[:space:]]*$' # command line without line number
RegexpCMD='^[[:space:]]+[[:digit:]]+[[:space:]]+trafikito_[a-zA-Z0-9_]+="[^"]+"[[:space:]]*$' # command line with line number
RegexpCMT='^[[:space:]]+[[:digit:]]+[[:space:]]+#'        # comments with line number (leading space okay)
RegexpSPC='^[[:space:]]+[[:digit:]]+[[:space:]]*$'        # blank lines with line number
RegexpValid="$RegexpCMD|$RegexpCMT|$RegexpSPC"            # valid lines used later for error feedback

# keep these 2 close to regexp definitions :-)
fn_valid_commands() {
    egrep $RegexpCommand $BASEDIR/available_commands.sh
}

fn_invalid_commands() {
    nl -ba $BASEDIR/available_commands.sh | egrep -v $RegexpValid
}

# valid commands into $TMP_FILE and source it
fn_valid_commands >$TMP_FILE
. $TMP_FILE

# source function to set os facts || exit 1
. $BASEDIR/lib/set_os.sh

###################################################
# functions to handle logs instead of using syslog
###################################################

fn_log() {
    echo "`date +'%x %X'` $*" >>"$LOGFILE"
}

fn_debug() {
    if [ "$DEBUG" ]; then
        fn_log "DEBUG $*"
    fi
}

# check for curl exit code != 0
fn_check_curl_error() {
    result=$1
    where=$2
    if [ "$result" != "0" ]; then
        fn_log "** ERROR: curl returned curl error code $result $where: cannot complete run"
        exit 1  # okay here, but don't do it in wrapper
    fi
}

##############################################################
# function to convert a \n seperated string into a json array
##############################################################
fn_json()  {
    errcode=$1
    errfile=$2
    shift
    shift
    message=$*
    flag=0
    echo -n '['
    cat $errfile | while read x; do
        if [ $flag -ne 0 ]; then
            echo -n ','
        fi
        flag=1
        # protect " and strip \r, leading and trailing wspace
        token=`echo $x | sed -e 's/\r//' -e 's/"/\\\"/g'  -e 's/^ *//' -e 's/ *$//'`
        echo -n \"$token\"
    done
    echo ']'
}

###############################################
# function to log and send an error to upstream
###############################################
fn_send_error() {
    errcode=$1
    errfile=$2
    shift
    shift
    message=$*
    json=`fn_json $errcode $errfile $message`
    fn_log "** ERROR: $message"
    fn_log "   details: $json"
    # test age of error
    last=0
    if [ -f "$BASEDIR/error.$errcode" ]; then
        last=`cat $BASEDIR/error.$errcode`
    fi
    now=`date +%s`
    age=$(( now - last ))
    if [ $age -gt 86400 ]; then
        fn_log "         reporting error to trafikito"
        # TODO
        ###############################################################################
        #curl --request POST --silent --retry 3 --retry-delay 1 --max-time 30  \
        #     --url     "$URL/v2/agent/error_feedback" \
        #     --header  "Content-Type: application/json" \
        #     --data "{ \"code\": \"$errcode\", \"message\": \"$message\", \"details\": \"$json\" }"
        # check for curl error
        #fn_check_curl_error $? 'sending error'
        ###############################################################################
        fn_log "         done"
        echo $now >$BASEDIR/var/error-$errcode
    else
        fn_log "          not reported to trafikito"
    fi
}

##########################################################
# function to define:
#   $CALL_TOKEN
#   $COMMANDS_TO_RUN: commands to execute from Trafikito
#   $AGENT_NEW_VERSION: current_agent_version for dynamic updates
#   $CYCLE_DELAY: seconds to delay this cycle
#   $WIDGETS: , delimited list of widgets to install
# returns:
#   0 success
#   1 error and log error
##########################################################
fn_get_config() {
    fn_debug "Previous hash: $CALL_TOKEN"

    data=`curl --request POST --silent --retry 3 --retry-delay 1 --max-time 30  \
               --url     "$URL/v2/agent/get_config" \
               --header  "Content-Type: application/json" \
               --data "{ \"serverId\": \"$SERVER_ID\", \"serverApiKey\": \"$API_KEY\", \"previous\": \"$CALL_TOKEN\" }" `
    # check for curl error
    fn_check_curl_error $? 'getting config'
    # check for trafikito error
    if [ -z "$data" ]; then
        fn_log "curl returned no data: cannot complete run"
        return 1
    fi
    echo "$data" | grep -q error
    if [ $? -eq 0 ]; then
        # {"error":{"code":"#6d5jyjytjh","message":"SEND_DATA_ONCE_PER_MINUTE_OR_YOU_WILL_BE_BLOCKED","env":"production"},"data":null}
        error=`echo "$data" | sed -e 's/.*message":"//' -e 's/".*//'`
        fn_log "curl returned Trafikito error '$error': cannot complete run"
        return 1
    fi

    fn_debug "Got data: $data"

    # server removed from UI or other reason to stop?
    # create $BASEDIR/var/STOP because this user may not have super user access
    case $data in STOP*)
        fn_log "Stopping the agent. Reason: $data"
        echo $data >$BASEDIR/var/STOP
        exit 1
    esac

    case $data in =)
        if [ -f $LAST_CONFIG ]; then
            data=`cat $LAST_CONFIG`
        fi
        fn_debug "Using config from cache"
    esac

    fn_debug "Saving config to cache file"
    echo $data >$LAST_CONFIG

    # parse data
    set $data
    CALL_TOKEN=$1
    COMMANDS_TO_RUN=`echo $2 | sed -e 's/,/ /g'`
    AGENT_NEW_VERSION=$3
    CYCLE_DELAY=$4
    WIDGETS=`echo $5 | sed -e 's/,/ /g'`

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
        echo "*-*-*-*------------ Trafikito command: $cmd" >>$TMP_FILE
        # $cmd is validated. has trafikito_ prefix and is single word with a-Z and _ characters.
        cmd="$(eval echo "\$$cmd")"

        # $cmd command is set by user at available_commands.sh
        eval "$cmd >> $TMP_FILE 2>&1"
    else
        # can not execute command without trafikito_ prefix
        echo "Can not execute command without trafikito_ prefix. Command: $cmd"
    fi
}

##############################
# functions to do agent update
##############################
fn_download()
{
    case `hostname -f` in
        *home) echo "http://tui.home/trafikito/$1" ;;
            *) echo "$URL/v2/agent/get_agent_file?file=$1 -H 'Cache-Control: no-cache' -H 'Content-Type: text/plain'"
    esac
}

fn_upgrade()
{
    fn_debug "*** Starting to download agent files"
    curl -X POST --silent --retry 3 --retry-delay 1 --max-time 30 --output "${BASEDIR}/trafikito" `fn_download trafikito` > /dev/null
    fn_check_curl_error $? "downloading trafikito"
    fn_debug "*** 1/5 done"
    curl -X POST --silent --retry 3 --retry-delay 1 --max-time 30 --output "${BASEDIR}/uninstall.sh" `fn_download uninstall.sh` > /dev/null
    fn_check_curl_error $? "downloading uninstall"
    fn_debug "*** 2/5 done"
    curl -X POST --silent --retry 3 --retry-delay 1 --max-time 30 --output "${BASEDIR}/lib/trafikito_wrapper.sh" `fn_download lib/trafikito_wrapper.sh` > /dev/null
    fn_check_curl_error $? "downloading wrapper"
    fn_debug "*** 3/5 done"
    curl -X POST --silent --retry 3 --retry-delay 1 --max-time 30 --output "${BASEDIR}/lib/trafikito_agent.sh" `fn_download lib/trafikito_agent.sh` > /dev/null
    fn_check_curl_error $? "downloading agent"
    fn_debug "*** 4/5 done"
    curl -X POST --silent --retry 3 --retry-delay 1 --max-time 30 --output "${BASEDIR}/lib/set_os.sh" `fn_download lib/set_os.sh` > /dev/null
    fn_check_curl_error $? "downloading set_os"
    fn_debug "*** 5/5 done"

    chmod +x $BASEDIR/trafikito $BASEDIR/uninstall.sh $BASEDIR/lib/*
}

##########################
# install a widget
##########################
fn_install_trafikito_widget() {
    # can execute only commands with trafikito_ in it
    WIDGET_ID=$1
    data=`curl --request POST --retry 3 --retry-delay 1 --max-time 30  \
               --url     "$URL/v2/widget/get-command" \
               --header  "Content-Type: application/json" \
               --data "{ \"widgetId\": \"$WIDGET_ID\" }"`
    fn_check_curl_error $? "installing widget $WIDGET_ID"

    # check that we got a valid command
    fn_invalid_command >$TMP_FILE
    if [ -s $TMP_FILE ]; then
        fn_send_error 102 $TMP_FILE 'error when installing widget'
        return
    fi

    # add command
    echo $data >>$BASEDIR/available_commands.sh

    # TODO check this code. Update: widget install endpoint must get sample output executed on this machine

    CMD=`echo $data | awk -F "=" '{print $1}'`
    REAL_COMMAND=`echo $data | awk -F "=" '{print $2}'`

    WIDGET_OUTPUT_FILE="$BASEDIR/var/widget_output_$WIDGET_ID.tmp"
    echo "*-*-*-*------------ Trafikito command: $REAL_COMMAND" >$WIDGET_OUTPUT_FILE
    eval "$REAL_COMMAND" >>$WIDGET_OUTPUT_FILE"

    installResult=`curl --request POST --silent --retry 3 --retry-delay 1 --max-time 30 \
     --url     $URL/v2/widget/install \
     --form    output=@$WIDGET_OUTPUT_FILE \
     --form    serverId=$SERVER_ID \
     --form    widgetId=$WIDGET_ID \
     --form    cmd=$CMD \
     --form    serverApiKey=$API_KEY`

    fn_check_curl_error $? "confirming widget $WIDGET_ID installed"
    # remove temp file
    rm $WIDGET_OUTPUT_FILE >/dev/null 2>&1
}

##################################################
# start of main
##################################################
fn_log "+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-"
fn_log "Agent v${AGENT_VERSION} run started"

if [ -f $BASEDIR/var/STOP ]; then
    fn_log `cat $BASEDIR/var/STOP`
    exit 1
fi


# send errors in available_commands.sh with line numbers to upstream
fn_invalid_commands >$TMP_FILE
if [ -s $TMP_FILE ]; then
    fn_send_error 100 $TMP_FILE "error in $BASEDIR/available_commands.sh"
fi

fn_set_os

# get config from trafikito
fn_get_config

fn_debug "    CALL_TOKEN $CALL_TOKEN"
fn_debug "    COMMANDS_TO_RUN $COMMANDS_TO_RUN"
fn_debug "    AGENT_NEW_VERSION $AGENT_NEW_VERSION"
fn_debug "    CYCLE_DELAY $CYCLE_DELAY"
fn_debug "    WIDGETS $WIDGETS"

if [ $? -ne 0 ]; then
    fn_log "Skipping this run"
    exit 1
fi

# save CYCLE_DELAY for wrapper
#CYCLE_DELAY=2
echo $CYCLE_DELAY   >$BASEDIR/var/cycle_delay.tmp

# create new tmp file
>$TMP_FILE

# Run commands and send results to tmp file
for cmd in $COMMANDS_TO_RUN
do
    fn_log "Running $cmd"
    fn_execute_trafikito_cmd "$cmd"
    fn_log "  $cmd is done"
done

# Install widgets
for widget in $WIDGETS
do
    fn_log "Installing $widget"
    fn_install_trafikito_widget "$widget"
    fn_log "  $widget installation is done"
done

# collect available commands from available_commands.sh
echo "*-*-*-*------------ Available commands:" >>$TMP_FILE
fn_valid_commands >>$TMP_FILE;

TIME_TOOK_LAST_TIME=0
if [ -f $BASEDIR/var/time_took_last_time.tmp ]; then
    TIME_TOOK_LAST_TIME=`cat $BASEDIR/var/time_took_last_time.tmp`
fi

saveResult=`curl --request POST --silent --retry 3 --retry-delay 1 --max-time 30 \
     --url     $URL/v2/agent/save_output \
     --form    output=@$TMP_FILE \
     --form    timeTookLastTime=$TIME_TOOK_LAST_TIME \
     --form    serverId=$SERVER_ID \
     --form    serverApiKey=$API_KEY`
fn_check_curl_error $? "saving result"
if [ "$saveResult" = "OK" ]; then
    fn_debug "saveResult: $saveResult"
else
    echo $saveResult >$TMP_FILE
    fn_send_error 101 $TMP_FILE "error in saveResult"
fi

fn_debug "DONE!"

END=$(date +%s)
echo "$(($END-$START))" >$BASEDIR/var/time_took_last_time.tmp

# test if need to upgrade/downgrade agent
if [ "$AGENT_VERSION" != "$AGENT_NEW_VERSION" ]; then
    fn_log "Changing this agent (version $AGENT_VERSION) to version $AGENT_NEW_VERSION"
    fn_upgrade
fi

fn_log "agent run complete";

