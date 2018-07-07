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

if [ $# -ne 2 ]; then
    echo "Usage: sh $0 <api_key> <server_id>"
    exit 1
fi
api_key=$1
server_id=$1

# running as root or user
RUNAS="nobody"
WHOAMI=`whoami`
if [ "$WHOAMI" != "root" ]; then
cat << STOP
    You are not root: the preferred way to install trafikito 
    is by using root. This will cause the agent to be run as
    the user 'nobody' which will improve security.
    To install as root either log in as root and execute the
    script or use 'sudo sh $0'

STOP
    echo -n "Press ^C to exit and rerun or run agent as $WHOAMI: "; read x
    RUNAS=$WHOAMI
fi

# install
BASEDIR="`pwd`/trafikito"
echo -n "Going to install trafikito in $BASEDIR (^C to change directory): "; read x

mkdir $BASEDIR 2>/dev/null
if [ $? -ne 0 ]; then
    echo -n "Found existing $BASEDIR: okay to remove it? (^C to break) "; read x
    rm -rf $BASEDIR
    mkdir $BASEDIR || exit 1
fi

LIBDIR="$BASEDIR/lib"
mkdir $LIBDIR
FUNCDIR="$BASEDIR/functions"
mkdir $FUNCDIR

# build config
CONFIG="$BASEDIR/trafikito.cfg"
cat >$CONFIG <<STOP
# Server API key
api_key=$api_key
# This server id at Trafikito.com
server_id=$server_id
# Temporary file used to gather output of commands. Must be readable and writable
tmp_file=/opt/trafikito/trafikito_tmp.txt
# Trafikito API URLs
url_output=https://api.trafikito.com/v1/agent/output
url_get_config=https://api.trafikito.com/v1/agent/get
STOP

# figure out how to download the rest of the scripts
# at this stage not sure should use curl or wget so build the library script here
# but will need installBinary() later for reconfigure.sh and not a good idea to
# have the code at more than one place :-)

cat >$LIBDIR/packages.lib <<STOP
###################################################
# do not edit: all edits to this file will be lost!
###################################################

# function to install a binary (just in case some binaries are in a package)
installBinary() {
    binary=$1
    package=$binary
    echo -n "  Press <enter> to install $package (^C to stop): "; read x
    if [ -x /usr/bin/apt-get ]; then # Debian
        /usr/bin/apt-get -y install $package
        STATUS=$?
    elif [ -x /usr/bin/yum ]; then # RedHat
        /usr/bin/yum -y install $package
        STATUS=$?
    elif [ -x /sbin/apk ]; then # alpine
        sbin/apk -y install $package
        STATUS=$?
    else
        echo "ERROR: this system's package manager is not supported"
        exit 1
    fi
    if [ $STATUS -ne 0 ]; then
        echo "ERROR: Installation failed"
        exit 1
    fi
}
STOP

echo "Looking for tool to talk to trafikito..."
AGENTLIST="curl wget"
for agent in $AGENTLIST; do
    echo -n "  $agent: "
    x=`which $agent`
    if [ $? -eq 0 ]; then
        echo "found $x"
        TXFR=$agent
        EXEC=$x
        break
    else
        echo "not found"
    fi
done
if [ -z "$TXFR" ]; then
    echo "  Could not find a tool to talk to trafikito"
    installBinary curl
fi

# build the transfer library
if [ "$TXFR" = "curl" ]; then

cat >"$LIBDIR/transfer.lib" <<STOP

# function to get files using curl
getfile() {
    source_url=\$1
    destination=\$2
    curl -s -X POST \$source_url --retry 3 --retry-delay 1 --max-time 30 >\$destination
    # TODO need error handling!
}

STOP

elif [ "$TXFR" = "wget" ]; then

cat >"$LIBDIR/transfer.lib" <<STOP

# function to get files using wget
getfile() {
}

STOP

else
    echo "ASSERT ERROR TXFR = $TXFR"
    exit 1
fi

# download agent's files
. $LIBDIR/transfer.lib

# TODO
URL="https://api.trafikito.com/v1/agent/get_agent_file?file="
URL="http://tui.home/trafikito/get_agent_file?file="

# redefine getfile for demo TODO
getfile() {
    source_url=$1
    dest=$2
    source=`echo $dest | sed s#$BASEDIR#..#`
    cp $source $dest
}

echo "Downloading functions:"
echo "* 1/9..."
getfile "${URL}functions/execute_all_commands.sh"       "${BASEDIR}/functions/execute_all_commands.sh"
echo "* 2/9..."
getfile "${URL}functions/execute_trafikito_cmd.sh"      "${BASEDIR}/functions/execute_trafikito_cmd.sh"
echo "* 3/9..."
getfile "${URL}functions/get_config_value.sh"           "${BASEDIR}/functions/get_config_value.sh"
echo "* 4/9..."
getfile "${URL}functions/send_output.sh"                "${BASEDIR}/functions/send_output.sh"
echo "* 5/9..."
getfile "${URL}functions/set_commands_to_run.sh"        "${BASEDIR}/functions/set_commands_to_run.sh"
echo "* 6/9..."
getfile "${URL}functions/set_environment.sh"            "${BASEDIR}/functions/set_environment.sh"
echo "* 7/9..."
getfile "${URL}functions/set_os.sh"                     "${BASEDIR}/functions/set_os.sh"
echo "* 8/9..."
getfile "${URL}functions/collect_available_commands.sh" "${BASEDIR}/functions/collect_available_commands.sh"
echo "* 9/9..."
getfile "${URL}reconfigure"                             "${BASEDIR}/reconfigure"

echo "Downloading agent..."
getfile "${URL}trafikito" "${BASEDIR}/trafikito"
getfile "${URL}trafikito-agent" "${BASEDIR}/trafikito-agent"
exit 1
chmod +x "${BASEDIR}/trafikito" "${BASEDIR}/trafikito-agent" "${BASEDIR}/reconfigure"

# reconfigure to build executables
${BASEDIR}/reconfigure

echo "STOP HERE TO NOT INSTALL STARTUP!"
exit 0

# configure restart
if [ "$WHOAMI" != "root" ]; then
echo <<STOP
Script was not installed as root: cannot configure startup
You can control the script manually with:
  $BASEDIR/trafikito {start|stop|restart|status}
STOP
fi

if [ -f /bin/systemd ]; then
    echo -n "You are running systemd: shall I configure, enable and start the agent? (^C to stop) "; read x

cat >/etc/systemd/system/trafikito.service <<STOP
[Unit]
Description=Trafikito Service
After=systemd-user-sessions.service
[Service]
Type=simple
ExecStart=/opt/trafikito/trafikito-agent
User=nobody
Group=nogroup
STOP

# TODO systemctl enable trafikito
systemctl start trafikito
systemctl status trafikito

fi

