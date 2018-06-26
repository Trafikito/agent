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

. "${DIR}/functions/get_config_value.sh"

fn_set_environment() {
    agent_version="14"
    config_file="${DIR}/trafikito.conf"
    lock_file="${DIR}/lock.file"
    api_key=$(fn_get_config_value api_key)
    server_id=$(fn_get_config_value server_id)
    tmp_file=$(fn_get_config_value tmp_file)
    random_number=$(fn_get_config_value random_number)
    url_output=$(fn_get_config_value url_output)
    url_get_config=$(fn_get_config_value url_get_config)
    
    if [ ! -w "$tmp_file" ]; then
        touch "$tmp_file" > /dev/null 2>&1
        chmod 777 "$tmp_file" > /dev/null 2>&1
    fi
    
    if [ ! -r "$tmp_file" ]; then
        touch "$tmp_file" > /dev/null 2>&1
        chmod 777 "$tmp_file" > /dev/null 2>&1
    fi    
}
