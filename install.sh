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

################################################################################################
################################################################################################
################################################################################################
################################################################################################
################################################################################################
################################################################################################

API_KEY=...
SERVER_ID=...

################################################################################################
################################################################################################
################################################################################################
################################################################################################
################################################################################################
################################################################################################

echo ""
echo ""
echo "  _____           __ _ _    _ _"
echo " |_   _| __ __ _ / _(_) | _(_) |_ ___"
echo "   | || '__/ _\` | |_| | |/ / | __/ _ \\"
echo "   | || | | (_| |  _| |   <| | || (_) |"
echo "   |_||_|  \__,_|_| |_|_|\_\_|\__\___/"
echo ""
echo ""
echo "    Trafikito.com agent installation"
echo ""
echo ""

################################################################################################
################################################################################################
############## config directories & file paths - start #########################################
################################################################################################
################################################################################################

# where trafikito agent will be installed.
INSTALLATION_DIR="/opt/trafikito"

CURRENT_PATH=$(pwd)

######################################  validation  ############################################

#### Installation dir

while true; do
    if [ -z $(echo "$INSTALLATION_DIR" | grep "trafikito$") ]; then
        INSTALLATION_DIR="${INSTALLATION_DIR}/trafikito"
    fi;

    rm -rf "$INSTALLATION_DIR" > /dev/null 2>&1
    mkdir -p "${INSTALLATION_DIR}/functions"
    chmod -R 755 "$INSTALLATION_DIR"

    if [ -d "$INSTALLATION_DIR" ]; then
        echo "Installing into: $INSTALLATION_DIR"
        break;
    else
        echo "Can not install into ${INSTALLATION_DIR}, enter another directory"
    fi;

    echo "Please enter installation dir."
    echo "(Leave empty to use: $CURRENT_PATH):"
    read INSTALLATION_DIR

    INSTALLATION_DIR=${INSTALLATION_DIR:-"$CURRENT_PATH"}

    while true
    do
        if [ -z $(echo "$INSTALLATION_DIR" | grep "\.\.") ]; then
            break;
        else
            echo "Please use absolute path:"
            read INSTALLATION_DIR
        fi;
    done
done

#### TMP FILE

TMP_FILE="${INSTALLATION_DIR}/trafikito_tmp.txt"

while true; do
    rm -f "$TMP_FILE" > /dev/null 2>&1
    touch "$TMP_FILE"

    if [ -f "$TMP_FILE" ]; then
        break;
    else
        echo "Can not create tmp file $TMP_FILE"
    fi;

    echo "Please enter path to tmp file."
    echo "(Leave empty to use: ${INSTALLATION_DIR}/trafikito_tmp.txt):"
    read TMP_FILE

    TMP_FILE=${TMP_FILE:-"${INSTALLATION_DIR}/trafikito_tmp.txt"}

    while true
    do
        if [ -z $(echo "$TMP_FILE" | grep "\.\.") ]; then
            break;
        else
            echo "Please use absolute path:"
            read TMP_FILE
        fi;
    done
done

# Make sure it's clean
echo "" > "$TMP_FILE"

#### LOG FILE

LOG_FILE="${INSTALLATION_DIR}/trafikito_agent.log"

while true; do
    rm -f "$LOG_FILE" > /dev/null 2>&1
    touch "$LOG_FILE"

    if [ -f "$LOG_FILE" ]; then
        break;
    else
        echo "Can not create log file $LOG_FILE"
    fi;

    echo "Please enter path to log file."
    echo "(Leave empty to use: ${INSTALLATION_DIR}/trafikito_agent.log):"
    read LOG_FILE

    LOG_FILE=${LOG_FILE:-"${INSTALLATION_DIR}/trafikito_agent.log"}

    while true
    do
        if [ -z $(echo "$LOG_FILE" | grep "\.\.") ]; then
            break;
        else
            echo "Please use absolute path:"
            read LOG_FILE
        fi;
    done
done

################################################################################################
################################################################################################
############## config directories & file paths - done ##########################################
################################################################################################
################################################################################################

touch "$INSTALLATION_DIR/lock.file"

fn_set_os() {
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

# set os
# set os_codename (may be empty string)
# set os_release (may be empty string)
# set centos_flavor (may be empty string)

fn_set_os

if [ -n "$SUDO_USER" ]; then
    USER="$SUDO_USER"
else
    USER=$(whoami)
fi

DIR="${0%/*}"

if  [ -z "$os" ]; then
    echo "Can not detect OS"
    exit 1
fi;

# download agent's files
URL="https://api.trafikito.com/v1/agent/get_agent_file?file="

echo "Downloading functions:"
echo "* 1/8..."
curl -s -X POST "${URL}functions/execute_all_commands.sh" --retry 3 --retry-delay 1 --max-time 30 > "${INSTALLATION_DIR}/functions/execute_all_commands.sh"
echo "* 2/8..."
curl -s -X POST "${URL}functions/execute_trafikito_cmd.sh" --retry 3 --retry-delay 1 --max-time 30 > "${INSTALLATION_DIR}/functions/execute_trafikito_cmd.sh"
echo "* 3/8..."
curl -s -X POST "${URL}functions/get_config_value.sh" --retry 3 --retry-delay 1 --max-time 30 > "${INSTALLATION_DIR}/functions/get_config_value.sh"
echo "* 4/8..."
curl -s -X POST "${URL}functions/send_output.sh" --retry 3 --retry-delay 1 --max-time 30 > "${INSTALLATION_DIR}/functions/send_output.sh"
echo "* 5/8..."
curl -s -X POST "${URL}functions/set_commands_to_run.sh" --retry 3 --retry-delay 1 --max-time 30 > "${INSTALLATION_DIR}/functions/set_commands_to_run.sh"
echo "* 6/8..."
curl -s -X POST "${URL}functions/set_environment.sh" --retry 3 --retry-delay 1 --max-time 30 > "${INSTALLATION_DIR}/functions/set_environment.sh"
echo "* 7/8..."
curl -s -X POST "${URL}functions/set_os.sh" --retry 3 --retry-delay 1 --max-time 30 > "${INSTALLATION_DIR}/functions/set_os.sh"
echo "* 8/8..."
curl -s -X POST "${URL}functions/collect_available_commands.sh" --retry 3 --retry-delay 1 --max-time 30 > "${INSTALLATION_DIR}/functions/collect_available_commands.sh"

echo "Downloading agent..."
curl -s -X POST "${URL}agent.sh" --retry 3 --retry-delay 1 --max-time 30 > "${INSTALLATION_DIR}/agent.sh"

echo "Generating initial settings"

echo "* Creating temporary file"
echo "" > "$TMP_FILE"

echo "** Checking average overall load 1/2"
echo "*-*-*-*------------ Trafikito command: uptime" >> "$TMP_FILE"
uptime >> "$TMP_FILE" 2>&1

echo "** Checking average overall load 2/2"
echo "*-*-*-*------------ Trafikito command: top -bcn1" >> "$TMP_FILE"
top -bcn1 >> "$TMP_FILE" 2>&1

echo "** Checking RAM information 1/2"
echo "*-*-*-*------------ Trafikito command: free" >> "$TMP_FILE"
free >> "$TMP_FILE" 2>&1

echo "** Checking RAM information 2/2"
echo "*-*-*-*------------ Trafikito command: vmstat -s" >> "$TMP_FILE"
vmstat -s >> "$TMP_FILE" 2>&1

echo "** Checking CPU load"
echo "*-*-*-*------------ Trafikito command: vmstat" >> "$TMP_FILE"
vmstat >> "$TMP_FILE" 2>&1

echo "** Checking CPU information 1/2"
echo "*-*-*-*------------ Trafikito command: cat /proc/cpuinfo | sed '/^\s*$/q' | grep -i 'cache\|core\|model\|mhz\|sibling\|vendor\|family'" >> "$TMP_FILE"
cat /proc/cpuinfo | sed '/^\s*$/q' | grep -i 'cache\|core\|model\|mhz\|sibling\|vendor\|family' >> "$TMP_FILE" 2>&1

echo "** Checking CPU information 2/2"
echo "*-*-*-*------------ Trafikito command: cat /proc/cpuinfo | sed '/^\s*$/q'" >> "$TMP_FILE"
cat /proc/cpuinfo | sed '/^\s*$/q' >> "$TMP_FILE" 2>&1

echo "** Checking CPU count"
echo "*-*-*-*------------ Trafikito command: cat /proc/cpuinfo 2>&1 | grep processor | wc -l" >> "$TMP_FILE"
cat /proc/cpuinfo 2>&1 | grep processor | wc -l >> "$TMP_FILE" 2>&1

echo "** Checking disk space information"
echo "*-*-*-*------------ Trafikito command: df -P" >> "$TMP_FILE"
df -P >> "$TMP_FILE" 2>&1

echo "** Checking top processes"
echo "*-*-*-*------------ Trafikito command: top -bcn1" >> "$TMP_FILE"
top -bcn1 >> "$TMP_FILE" 2>&1

echo "** Checking disk space human friendly information"
echo "*-*-*-*------------ Trafikito command: df -h" >> "$TMP_FILE"
df -h >> "$TMP_FILE" 2>&1

echo "** Checking hostname"
echo "*-*-*-*------------ Trafikito command: hostname" >> "$TMP_FILE"
hostname >> "$TMP_FILE" 2>&1

echo "** Checking active open network connections"
echo "*-*-*-*------------ Trafikito command: lsof -i | grep '\->' | wc -l" >> "$TMP_FILE"
lsof -i | grep '\->' | wc -l >> "$TMP_FILE" 2>&1

echo "** Checking count of open files"
echo "*-*-*-*------------ Trafikito command: lsof | wc -l" >> "$TMP_FILE"
lsof | wc -l >> "$TMP_FILE" 2>&1

echo "** Checking netstat stats"
echo "*-*-*-*------------ Trafikito command: netstat -i" >> "$TMP_FILE"
netstat -i >> "$TMP_FILE" 2>&1

echo "** Checking curl version"
echo "*-*-*-*------------ Trafikito command: curl --version" >> "$TMP_FILE"
curl --version >> "$TMP_FILE" 2>&1

echo "* Downloading available_commands.sh (in this file you can find list of commands used at data source settings on UI)"
curl -s -X POST -H "Content-Type: multipart/form-data" -F "output=@$TMP_FILE" -F "serverId=$SERVER_ID" -F "os=$os" -F "osCodename=$os_codename" -F "osRelease=$os_release" -F "centosFlavor=$centos_flavor" "${URL}available_commands.sh" --retry 3 --retry-delay 1 --max-time 30 > "${INSTALLATION_DIR}/available_commands.sh"

echo "* Downloading trafikito.conf (in this file you can find server's API key and ID)"
curl -s -X POST -F "apiKey=$API_KEY" -F "tmpFile=$TMP_FILE" -F "serverId=$SERVER_ID" "${URL}trafikito.conf" --retry 3 --retry-delay 1 --max-time 30 > "${INSTALLATION_DIR}/trafikito.conf"

echo "Making agent executable"
# Make agent file executable
chmod a+x "${INSTALLATION_DIR}/agent.sh"

# Fixing permissions
chown -R "$USER" "$INSTALLATION_DIR"

echo "Adding agent to crontab"
# Add agent to crontab
# https://unix.stackexchange.com/a/348716/200004

echo "" > "$TMP_FILE"

crontab -l -u "$USER" | grep -v 'trafikito/agent.sh' > "$TMP_FILE"
echo "* * * * * ${INSTALLATION_DIR}/agent.sh > $LOG_FILE" >> "$TMP_FILE"
crontab -u "$USER" "$TMP_FILE"

# Clean up
# Sometimes it fails to remove, so at least clean up
echo "Cleaning temporary files"
echo "" > "$TMP_FILE"

if [ -w "${DIR}/trafikito_agent_install.sh" ]; then
    echo "Removing installation script"
    rm "${DIR}/trafikito_agent_install.sh"
fi

echo ""
echo ""
echo ""
echo "Done. After 2-3 minutes you will see first monitoring information."
echo ""
echo "https://trafikito.com/"
echo ""
