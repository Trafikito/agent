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

fn_set_commands_to_run() {
    commands_to_run=`curl -s -X POST -H "Authorization: $API_KEY" \
                    --data "serverId=$SERVER_ID&agentVersion=$AGENT_VERSION&os=os&osCodename=os_codename&osRelease=os_release&centosFlavor=centos_flavor" \
                    "$URL_GET_CONFIG" --retry 3 --retry-delay 1 --max-time 30`
    echo $commands_to_run

    tmp=`echo $commands_to_run | grep '{"data":null,"error":{"code":"#q2w4544h4asa2gAefg53GHrfd","message":'`
    if [ -n "$tmp" ]; then
        ERROR="Error: Do not call more then once per minute. ANOTHER_REQUEST_IN_PROGRESS"
        return 1
    fi

    tmp=`echo "$commands_to_run" | grep "\"error\":{\"code\":\"#"`
    if [ -n "$tmp" ]; then
        ERROR="Error: Can not get commands to run: $tmp"
        return 1
    fi
        
    if [ -z "$commands_to_run" ];
    then
        ERROR="Error: received empty config from Trafikito.com. Probably a network outage?"
        return 1
    fi
    
    ERROR=""
    return 0
}
