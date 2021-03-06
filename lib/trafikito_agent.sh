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

# agent version: will be compared as a string
export AGENT_VERSION=55
export AGENT_NEW_VERSION=$AGENT_VERSION  # redefined in fn_set_available_commands

# basedir is $1 to enable this to run from anywhere
if [ $# -ne 1 ]; then
    echo "Usage: $0 <trafikito_base_dir>" 1>&2
    exit 1
fi
export BASEDIR=$1

# trim logfile to 1000 lines
export LOGFILE=$BASEDIR/var/trafikito.log
if [ -f $LOGFILE ]; then
    cp $LOGFILE $LOGFILE.bak
    tail -n 1000 $LOGFILE.bak >$LOGFILE
fi

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

DEBUG=1

fn_log "+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-"
fn_log "Agent v${AGENT_VERSION} run started."

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
    egrep $RegexpCommand
}

fn_invalid_commands() {
    nl -ba | egrep -v $RegexpValid
}

# valid commands into $TMP_FILE and source it
cat $BASEDIR/available_commands.sh | fn_valid_commands >$TMP_FILE
. $TMP_FILE

# source function to set os facts || exit 1
. $BASEDIR/lib/set_os.sh

# check for curl exit code != 0
fn_check_curl_error() {
    result=$1
    where=$2
    if [ "$result" != "0" ]; then
        fn_log "** ERROR: curl returned curl error code $result $where: cannot complete run"
        exit 1  # okay here, but don't do it in wrapper
    fi
}

# select which edge to use and which use as a fallback
API_EDGE="https://api.trafikito.com";

fn_select_edge ()
{
    API_EDGE_1="https://ap-southeast-1.api.trafikito.com"
    API_EDGE_2="https://eu-west-1.api.trafikito.com"
    API_EDGE_3="https://us-east-1.api.trafikito.com"

    # TODO while this is POSIX way to get random number it's time depended and creates spikes on edge during same second
    # big range to avoid unequal random value distribution on some systems
    DEFAULT_EDGE=`awk 'BEGIN{srand();print int(rand()*(12000-1))+1 }'`

    if [ "$DEFAULT_EDGE" -gt 4000 ]; then
        API_EDGE_1="https://eu-west-1.api.trafikito.com"
        API_EDGE_2="https://us-east-1.api.trafikito.com"
        API_EDGE_3="https://ap-southeast-1.api.trafikito.com"
    fi

    if [ "$DEFAULT_EDGE" -gt 8000 ]; then
        API_EDGE_1="https://us-east-1.api.trafikito.com"
        API_EDGE_2="https://ap-southeast-1.api.trafikito.com"
        API_EDGE_3="https://eu-west-1.api.trafikito.com"
    fi

    testData=`curl -X POST --silent --retry 3 --retry-delay 1 --max-time 30 -H 'Cache-Control: no-cache' -H 'Content-Type: text/plain' "$API_EDGE_1/v2/ping"`
    if [ "$testData" = "OK" ]; then
        API_EDGE="$API_EDGE_1"
    else
      testData=`curl -X POST --silent --retry 3 --retry-delay 1 --max-time 30 -H 'Cache-Control: no-cache' -H 'Content-Type: text/plain' "$API_EDGE_2/v2/ping"`
        if [ "$testData" = "OK" ]; then
            API_EDGE="$API_EDGE_2"
        else
          testData=`curl -X POST --silent --retry 3 --retry-delay 1 --max-time 30 -H 'Cache-Control: no-cache' -H 'Content-Type: text/plain' "$API_EDGE_3/v2/ping"`
          if [ "$testData" = "OK" ]; then
             API_EDGE="$API_EDGE_3"
          else
            fn_log "Network issues? Try again."
            exit 1;
          fi
        fi
    fi
}

fn_select_edge
fn_debug "Edge selected: $API_EDGE"

###############################################
# function to log and send an error to upstream
###############################################
fn_send_error() {
    errcode=$1
    errfile=$2
    message=$3
    details=$4
    fn_log "** ERROR: $message"
    # test age of error
    last=0
    if [ -f "$BASEDIR/error.$errcode" ]; then
        last=`cat $BASEDIR/error.$errcode`
    fi
    now=`date +%s`
    age=$(( now - last ))
    # report same error once per 1 minute
    if [ $age -gt 60 ]; then
        fn_log "         reporting error to trafikito"
        ###############################################################################
        curl --request POST --silent --retry 3 --retry-delay 10 --max-time 30 \
              --url "$API_EDGE/v2/agent/error_feedback" \
              --header 'cache-control: no-cache' \
              --header 'content-type: multipart/form-data' \
              -F "code=$errcode" \
              -F "message=$message" \
              -F "details=$details" \
              -F "serverApiKey=$API_KEY"

        fn_check_curl_error $? 'sending error'
        ###############################################################################
        fn_log "         done"
        echo $now >$BASEDIR/var/error-$errcode
    else
        fn_log "          not reported to Trafikito"
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
    if [ -f $LAST_CONFIG ]; then
        lastData=`cat $LAST_CONFIG`
        set $lastData
        CALL_TOKEN=`echo "$1" | sed -e 's/[^a-Z0-9]*//g'`
        if [ -z "$CALL_TOKEN" ]; then
            # TODO some distros erases all valid call tokens for any reason
            CALL_TOKEN="$1"
        fi
    fi

    fn_debug "Previous hash: $CALL_TOKEN"

    data=`curl --request POST --silent --retry 3 --retry-delay 1 --max-time 30  \
               --url     "$API_EDGE/v2/agent/get_config" \
               --header  "Content-Type: application/json" \
               --data "{ \"serverId\": \"$SERVER_ID\", \"serverApiKey\": \"$API_KEY\", \"previous\": \"$CALL_TOKEN\" }" `

    # check for curl error
    fn_check_curl_error $? 'getting config'
    # check for trafikito error
    fn_debug "Got cycle data: $data"

    if [ -z "$data" ]; then
        fn_log "curl returned no data: cannot complete run"
        return 1
    fi

    echo "$data" | grep -q error
    if [ $? -eq 0 ]; then
        # {"error":{"code":"#6d5jyjytjh","message":"SEND_DATA_ONCE_PER_MINUTE_OR_YOU_WILL_BE_BLOCKED"},"data":null}
        error=`echo "$data" | sed -e 's/.*message":"//' -e 's/".*//'`
        fn_send_error 104 "" "$error" "$data"
        fn_log "curl returned Trafikito error '$error': cannot complete run"
        return 1
    fi

    # data must be JSON or begin with STOP

    echo "$data" | grep -q "^{|STOP"
    if [ $? -eq 0 ]; then
        fn_send_error 105 "" "AGENT_INVALID_CYCLE_DATA" "$data"
        return 1
    fi

    # server removed from UI or other reason to stop?
    # create $BASEDIR/var/STOP because this user may not have super user access
    case $data in STOP*)
        fn_log "Stopping the agent. Reason: $data"
        fn_log "To uninstall the agent run this:"
        fn_log "sudo sh $BASEDIR/uninstall.sh"
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
    elif [ $(echo "$cmd" | grep "trafikito_" | sed "s/[^0-9a-zA-Z_]*//g") = "$cmd" ]; then
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
 echo "$API_EDGE/v2/agent/get_agent_file?file=$1"

#    fn_debug "Downloading... $API_EDGE/v2/agent/get_agent_file?file=$1 -H 'Cache-Control: no-cache' -H 'Content-Type: text/plain'"
#    case `hostname -f` in
#        *home) echo "http://tui.home/trafikito/$1" ;;
#            *) echo "$API_EDGE/v2/agent/get_agent_file?file=$1 -H 'Cache-Control: no-cache' -H 'Content-Type: text/plain'"
#    esac
}

fn_upgrade()
{
    fn_debug "*** Starting to download agent files"
    curl -X POST --silent --retry 3 --retry-delay 1 --max-time 30 -H 'Cache-Control: no-cache' -H 'Content-Type: text/plain' --output "${BASEDIR}/trafikito" `fn_download trafikito` > /dev/null
    fn_check_curl_error $? "downloading trafikito"
    fn_debug "*** 1/5 done"
    curl -X POST --silent --retry 3 --retry-delay 1 --max-time 30 -H 'Cache-Control: no-cache' -H 'Content-Type: text/plain' --output "${BASEDIR}/uninstall.sh" `fn_download uninstall.sh` > /dev/null
    fn_check_curl_error $? "downloading uninstall"
    fn_debug "*** 2/5 done"
    curl -X POST --silent --retry 3 --retry-delay 1 --max-time 30 -H 'Cache-Control: no-cache' -H 'Content-Type: text/plain' --output "${BASEDIR}/lib/trafikito_wrapper.sh" `fn_download lib/trafikito_wrapper.sh` > /dev/null
    fn_check_curl_error $? "downloading wrapper"
    fn_debug "*** 3/5 done"
    curl -X POST --silent --retry 3 --retry-delay 1 --max-time 30 -H 'Cache-Control: no-cache' -H 'Content-Type: text/plain' --output "${BASEDIR}/lib/trafikito_agent.sh" `fn_download lib/trafikito_agent.sh` > /dev/null
    fn_check_curl_error $? "downloading agent"
    fn_debug "*** 4/5 done"
    curl -X POST --silent --retry 3 --retry-delay 1 --max-time 30 -H 'Cache-Control: no-cache' -H 'Content-Type: text/plain' --output "${BASEDIR}/lib/set_os.sh" `fn_download lib/set_os.sh` > /dev/null
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
               --url     "$API_EDGE/v2/widget/get-command" \
               --header  "Content-Type: application/json" \
               --data "{ \"widgetId\": \"$WIDGET_ID\" }"`
    fn_check_curl_error $? "installing widget $WIDGET_ID"

    # check that we got a valid command
    echo $data | fn_invalid_commands >$TMP_FILE
    if [ -s $TMP_FILE ]; then
        fn_debug "Invalid command while installing widget:"
        fn_debug `cat $TMP_FILE`
        fn_send_error 102 $TMP_FILE 'AGENT_INSTALL_WIDGET_FAILED_INVALID_COMMAND'
        return
    else
        rm -f $BASEDIR/var/error-102
    fi

    # add command
    echo $data >>$BASEDIR/available_commands.sh

    CMD=`echo $data | awk -F "=" '{print $1}'`
    REAL_COMMAND=`echo $data | awk -F "=" '{print $2}' | sed -e 's/"//g'`

    fn_debug "Widget cmd: $CMD"
    fn_debug "Widget real command: $REAL_COMMAND"
    fn_debug "$CMD output:"

    WIDGET_OUTPUT_FILE="$BASEDIR/var/widget_output_$WIDGET_ID.tmp"
    echo "*-*-*-*------------ Trafikito command: $REAL_COMMAND" >$WIDGET_OUTPUT_FILE
    eval "$REAL_COMMAND >> $WIDGET_OUTPUT_FILE 2>&1"

    fn_debug `cat $WIDGET_OUTPUT_FILE`

    installResult=`curl --request POST --silent --retry 3 --retry-delay 1 --max-time 30 \
     --url     $API_EDGE/v2/widget/install \
     --form    output=@$WIDGET_OUTPUT_FILE \
     --form    serverId=$SERVER_ID \
     --form    widgetId=$WIDGET_ID \
     --form    cmd=$CMD \
     --form    serverApiKey=$API_KEY`

    fn_debug "Install result: $installResult"

    fn_check_curl_error $? "confirming widget $WIDGET_ID installed"
    # remove temp file
    rm "$WIDGET_OUTPUT_FILE" >/dev/null 2>&1
}

##################################################
# start of main
##################################################

if [ -f $BASEDIR/var/STOP ]; then
    fn_log "Found file at $BASEDIR/var/STOP:"
    fn_log `cat $BASEDIR/var/STOP`
    fn_log "Terminating this cycle. STOP file is often created when server is removed using dashboard."
    fn_log "To uninstall the agent run this:"
    fn_log "sudo sh $BASEDIR/uninstall.sh"
    exit 1
fi

# send errors in available_commands.sh with line numbers to upstream
cat $BASEDIR/available_commands.sh | fn_invalid_commands >$TMP_FILE

if [ -s $TMP_FILE ]; then
    fn_debug "Invalid commands:"
    fn_debug `cat $TMP_FILE`
    fn_send_error 100 $TMP_FILE "AGENT_INVALID_COMMANDS" "error in $BASEDIR/available_commands.sh"
else
    rm -f $BASEDIR/var/error-100
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

# collect only valid available commands from available_commands.sh
echo "*-*-*-*------------ Available commands:" >>$TMP_FILE
cat $BASEDIR/available_commands.sh | fn_valid_commands >>$TMP_FILE;

TIME_TOOK_LAST_TIME=0
if [ -f $BASEDIR/var/time_took_last_time.tmp ]; then
    TIME_TOOK_LAST_TIME=`cat $BASEDIR/var/time_took_last_time.tmp`
fi

saveResult=`curl --request POST --silent --retry 3 --retry-delay 1 --max-time 30 \
     --url     $API_EDGE/v2/agent/save_output \
     --form    output=@$TMP_FILE \
     --form    timeTookLastTime=$TIME_TOOK_LAST_TIME \
     --form    serverId=$SERVER_ID \
     --form    serverApiKey=$API_KEY`
fn_check_curl_error $? "saving result"
if [ "$saveResult" = "OK" ]; then
    fn_debug "saveResult: $saveResult"
    rm -f $BASEDIR/var/error-101
else
    echo $saveResult >$TMP_FILE
    fn_send_error 101 $TMP_FILE "AGENT_SAVE_RESULT_FAILED"
fi

fn_debug "Saving results done!"

# Install widgets
for widget in $WIDGETS
do
    fn_log "Installing $widget"
    fn_install_trafikito_widget "$widget"
    fn_log "Widget  $widget installation is done"
done

END=$(date +%s)
echo "$(($END-$START))" >$BASEDIR/var/time_took_last_time.tmp

# test if need to upgrade/downgrade agent
if [ "$AGENT_VERSION" != "$AGENT_NEW_VERSION" ]; then
    fn_log "Changing this agent (version $AGENT_VERSION) to version $AGENT_NEW_VERSION"
    fn_upgrade
fi

fn_log "agent run complete";

