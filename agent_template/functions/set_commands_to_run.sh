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
    if command -V curl > /dev/null 2>&1; then
        
        # curl is available - call with curl
        # -s = silent
        # -X = custom HTTP method
        # -H = custom Header
        # -F = add form data. Use @ to add binary format of the content
        # -retry = it will retry this number of times before giving up
        # ---retry-delay = sleep this amount of time before each retry when a transfer has failed
        # --max-time = maximum time in seconds that you allow the whole operation to take
        
        commands_to_run="$(curl -s -X POST -H "Authorization: $api_key" --data "serverId=$server_id&agentVersion=$agent_version&os=$os&osCodename=$os_codename&osRelease=$os_release&centosFlavor=$centos_flavor" "$url_get_config" --retry 3 --retry-delay 1 --max-time 30)"
        
        tmp=$(echo "$commands_to_run" | grep "{\"data\":null,\"error\":{\"code\":\"#q2w4544h4asa2gAefg53GHrfd\",\"message\":\"")
        
        if [ -n "$tmp" ];
        then
            echo "Error: Do not call more then once per minute. ANOTHER_REQUEST_IN_PROGRESS"
            exit 1
        fi

        tmp=$(echo "$commands_to_run" | grep "\"error\":{\"code\":\"#")

        if [ -n "$tmp" ];
        then
            echo "Error: Can not get commands to run: $tmp"
            exit 1
        fi
        
        if [ -z "$commands_to_run" ];
        then
            echo "Error: received empty config from Trafikito.com. Check agent config or re-install agent."
            exit 1
        fi
        
    else
        echo "curl not found. Please install curl and try again."
        exit 1
    fi
}
