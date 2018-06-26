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

###########################################
# This agent should work on any linux machine.
# Dependencies: Shell Script (sh), grep, sed, eval, awk, head, curl, touch, chmod
###########################################

DIR="${0%/*}"

. "${DIR}/functions/set_os.sh"
. "${DIR}/functions/set_environment.sh"
. "${DIR}/functions/execute_trafikito_cmd.sh"
. "${DIR}/functions/send_output.sh"
. "${DIR}/functions/set_commands_to_run.sh"
. "${DIR}/functions/execute_all_commands.sh"
. "${DIR}/functions/collect_available_commands.sh"

# set agent_version
# set config_file
# set lock_file
# set api_key
# set server_id
# set tmp_file
fn_set_environment

# echo "env set agent_version: $agent_version"
# echo "env set config_file: $config_file"
# echo "env set api_key: $api_key"
# echo "env set server_id: $server_id"
# echo "env set tmp_file: $tmp_file"

# set os
# set os_codename (may be empty string)
# set os_release (may be empty string)
# set centos_flavor (may be empty string)
fn_set_os

# Check if another script is not running already

if [ -r "$lock_file" ]; then
    LAST_RUN_AT="$(cat "$lock_file")"
    NOW="$(date +%s)"

    LAST_BEFORE_S="9999999"

    if [ -n "$NOW" ]; then
        if [ -n "$LAST_RUN_AT" ]; then
            LAST_BEFORE_S="$(($NOW-$LAST_RUN_AT))"
        fi;
    fi;

    if [ "$LAST_BEFORE_S" -lt "90" ]; then
        echo "Some other script was running during last 90 sec (${LAST_BEFORE_S}s. ago). Exit. It may be still running."
        exit 1
    fi;
fi;

# Don't run all scripts at same time, add some random delay for 1st call
sleep "$random_number"

while sleep 1;
do

    if [ ! -r "${DIR}/functions/set_os.sh" ]; then
        echo "Missing agent files. Exiting."
        exit 1;
    fi;
    if [ ! -r "${DIR}/functions/set_environment.sh" ]; then
        echo "Missing agent files. Exiting."
        exit 1;
    fi;
    if [ ! -r "${DIR}/functions/execute_trafikito_cmd.sh" ]; then
        echo "Missing agent files. Exiting."
        exit 1;
    fi;
    if [ ! -r "${DIR}/functions/send_output.sh" ]; then
        echo "Missing agent files. Exiting."
        exit 1;
    fi;
    if [ ! -r "${DIR}/functions/set_commands_to_run.sh" ]; then
        echo "Missing agent files. Exiting."
        exit 1;
    fi;
    if [ ! -r "${DIR}/functions/execute_all_commands.sh" ]; then
        echo "Missing agent files. Exiting."
        exit 1;
    fi;
    if [ ! -r "${DIR}/functions/collect_available_commands.sh" ]; then
        echo "Missing agent files. Exiting."
        exit 1;
    fi;

    # recreate lock file if deleted
    if [ ! -r "$lock_file" ]; then
        touch "$lock_file"
    fi;

    LAST_RUN_AT="$(cat "$lock_file")"
     TrNOW="$(date +%s)"

    LAST_BEFORE_S="9999999"

    if [ -n "$NOW" ]; then
        if [ -n "$LAST_RUN_AT" ]; then
            LAST_BEFORE_S="$(($NOW-$LAST_RUN_AT))"
        fi;
    fi;

    if [ "$LAST_BEFORE_S" -gt "60" ]; then
            date +%s > "$lock_file"

            # set commands_to_run E.g.: commands_to_run="63e374bd-92be-4275-a985-ba2b8d2a953d,trafikito_uptime,trafikito_total_ram"
            fn_set_commands_to_run

            # Clean up tmp file
            echo "" > "$tmp_file"

            # Run commands and send results to tmp file
            fn_execute_all_commands

            # collect available commands from available_commands.sh
            fn_collect_available_commands

            # Send outputs to Trafikito API
            fn_send_output_to_trafikito

            # Clean up tmp file
            echo "" > "$tmp_file"

            # How this all works?
            #
            # https://www.websequencediagrams.com/#open=354215
            #
            # User->Trafikito: Add server
            # User->Server: Run install script
            # Server->InstallScript: Run install script
            # InstallScript->Trafikito: Gets default config
            # InstallScript->Server: installs agent

            # Server->Agent: Run Agent (every minute)
            # Agent->Trafikito: Request server config with API key
            # Trafikito->Agent: Give commands to run + call token
            # Agent->Agent: runs commands
            # Agent->Trafikito: Send outputs + call token
    fi;

done;
