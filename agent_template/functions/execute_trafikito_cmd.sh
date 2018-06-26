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

. "${DIR}/available_commands.sh"

fn_execute_trafikito_cmd() {
    # can execute only commands with trafikito_ in it
    cmd="$1"
    
    if [ -z "$cmd" ]; then
        # can not execute empty string
        echo "No command specified for execute_trafikito_cmd. Command: $cmd"
        elif [ $(echo "$cmd" | grep "trafikito_" | sed "s/[^a-zA-Z_]*//g") = "$cmd" ]; then
        # can execute, let's do it. Echo commands delimiter:
        echo "*-*-*-*------------ Trafikito command: $cmd" >> "$tmp_file"
        # $cmd is validated. has trafikito_ prefix and is single word with a-Z and _ characters.
        cmd="$(eval echo "\$$cmd")"
        
        # $cmd command is set by user at available_commands.sh
        eval "$cmd >> $tmp_file 2>&1"
        echo "done executing: $cmd"
    else
        # can not execute command without trafikito_ prefix
        echo "Can not execute command without trafikito_ prefix. Command: $cmd"
    fi
}
