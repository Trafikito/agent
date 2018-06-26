#!/usr/bin/env sh

# /*
#  * Copyright (C) Nginx, Inc.
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

# this will set variables "os", "os_codename", "os_release" and "centos_flavor"

# Sample call:
# get_os_name
# echo "$os"

fn_set_os() {
    
    centos_flavor="centos"
    
    # Use lsb_release if possible
    if command -V lsb_release > /dev/null 2>&1; then
        os=`lsb_release -is | tr '[:upper:]' '[:lower:]'`
        os_codename=`lsb_release -cs | tr '[:upper:]' '[:lower:]'`
        os_release=`lsb_release -rs | sed 's/\..*$//'`
        
        if [ "$os" = "redhatenterpriseserver" -o "$os" = "oracleserver" ]; then
            os="centos"
            centos_flavor="red hat linux"
        fi
        # Otherwise it's getting a little bit more tricky
    else
        if ! ls /etc/*-release > /dev/null 2>&1; then
            os=`uname -s | \
            tr '[:upper:]' '[:lower:]'`
        else
            os=`cat /etc/*-release | grep '^ID=' | \
            sed 's/^ID=["]*\([a-zA-Z]*\).*$/\1/' | \
            tr '[:upper:]' '[:lower:]'`
            
            if [ -z "$os" ]; then
                if grep -i "oracle linux" /etc/*-release > /dev/null 2>&1 || \
                grep -i "red hat" /etc/*-release > /dev/null 2>&1; then
                    os="rhel"
                else
                    if grep -i "centos" /etc/*-release > /dev/null 2>&1; then
                        os="centos"
                    else
                        os="linux"
                    fi
                fi
            fi
        fi
        
        case "$os" in
            ubuntu)
                os_codename=`cat /etc/*-release | grep '^DISTRIB_CODENAME' | \
                sed 's/^[^=]*=\([^=]*\)/\1/' | \
                tr '[:upper:]' '[:lower:]'`
            ;;
            debian)
                os_codename=`cat /etc/*-release | grep '^VERSION=' | \
                sed 's/.*(\(.*\)).*/\1/' | \
                tr '[:upper:]' '[:lower:]'`
            ;;
            centos)
                os_codename=`cat /etc/*-release | grep -i 'centos.*(' | \
                sed 's/.*(\(.*\)).*/\1/' | head -1 | \
                tr '[:upper:]' '[:lower:]'`
                # For CentOS grab release
                os_release=`cat /etc/*-release | grep -i 'centos.*[0-9]' | \
                sed 's/^[^0-9]*\([0-9][0-9]*\).*$/\1/' | head -1`
            ;;
            rhel|ol)
                os_codename=`cat /etc/*-release | grep -i 'red hat.*(' | \
                sed 's/.*(\(.*\)).*/\1/' | head -1 | \
                tr '[:upper:]' '[:lower:]'`
                # For Red Hat also grab release
                os_release=`cat /etc/*-release | grep -i 'red hat.*[0-9]' | \
                sed 's/^[^0-9]*\([0-9][0-9]*\).*$/\1/' | head -1`
                
                if [ -z "$release" ]; then
                    os_release=`cat /etc/*-release | grep -i '^VERSION_ID=' | \
                    sed 's/^[^0-9]*\([0-9][0-9]*\).*$/\1/' | head -1`
                fi
                
                os="centos"
                centos_flavor="red hat linux"
            ;;
            amzn)
                os_codename="amazon-linux-ami"
                release_amzn=`cat /etc/*-release | grep -i 'amazon.*[0-9]' | \
                sed 's/^[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\).*$/\1/' | \
                head -1`
                os_release="latest"
                
                os="amzn"
                centos_flavor="amazon linux"
            ;;
            *)
                os_codename=""
                os_release=""
            ;;
        esac
    fi
}
