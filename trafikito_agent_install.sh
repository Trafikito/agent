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

export PATH=/usr/sbin:/usr/bin:/sbin:/bin

if [ $# -ne 3 ]; then
    echo "Usage: sh $0 <api_key> <server_id> <start_minute>"
    exit 1
fi
API_KEY=$1
SERVER_ID=$2
START_ON=$3

# running as root or user ?
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

# create std subdirs
mkdir $BASEDIR/etc
mkdir $BASEDIR/lib
mkdir $BASEDIR/var

# build config
CONFIG="$BASEDIR/etc/trafikito.cfg"
cat >$CONFIG <<STOP
export RUNAS=$RUNAS
export API_KEY=$API_KEY
export SERVER_ID=$SERVER_ID
export START_ON=$START_ON
export TMP_FILE=$BASEDIR/var/trafikito.tmp
export URL_OUTPUT=https://api.trafikito.com/v1/agent/output
export URL_GET_CONFIG=https://api.trafikito.com/v1/agent/get
STOP

# at this stage curl may not be installed yet
# but will need installBinary() later for reconfigure and not a good idea to
# have the code at more than one place :-)

cat >$BASEDIR/lib/utilities.sh <<STOP
###################################################
# do not edit: all edits to this file will be lost!
###################################################

# function to install a binary (just in case some binaries are in a package)
installBinary() {
    binary=\$1
    package=\$binary

    if [ \`whoami\` != 'root' ]; then
        echo "Sorry! Need root privilege to install '\$binary'"
        echo "You have to install it manually"
        exit 1
    fi

    echo -n "  Press <enter> to install \$package (^C to stop): "; read x
    if [ -x /usr/bin/apt-get ]; then # Debian
        /usr/bin/apt-get -y install \$package
        return `which \$binary`
    elif [ -x /usr/bin/yum ]; then # RedHat
        /usr/bin/yum -y install \$package
        return `which \$binary`
    elif [ -x /sbin/apk ]; then # alpine
        sbin/apk -y install \$package
        return `which \$binary`
    else
        echo "ERROR: this system's package manager is not supported"
        exit 1
    fi
}

# function to get files using curl
getfile() {
    source_url=\$1
    destination=\$2
    curl -s -X POST \$source_url --retry 3 --retry-delay 1 --max-time 30 >\$destination
    # TODO need error handling!
}

STOP

# source the file just generated
. $BASEDIR/lib/utilities.sh

# install curl
echo -n "Checking for curl..."
curl=`which curl`
if [ -z $curl ]; then
    echo "not found"
    TXFR=`installBinary curl`
else
    echo "found $curl"
    TXFR=$curl
fi
if [ -z "$TXFR" ]; then
    echo "  Looks like your distro does not have curl: please contact trafikito support"  # TODO
fi

# TODO
URL="https://api.trafikito.com/v1/agent/get_agent_file?file="
URL="http://tui.home/trafikito/"

echo "Downloading functions:"
echo "  * 1/8..."
getfile "${URL}lib/execute_all_commands.sh"       "${BASEDIR}/lib/execute_all_commands.sh"
echo "  * 2/8..."
getfile "${URL}lib/execute_trafikito_cmd.sh"      "${BASEDIR}/lib/execute_trafikito_cmd.sh"
echo "  * 3/8..."
getfile "${URL}lib/get_config_value.sh"           "${BASEDIR}/lib/get_config_value.sh"
echo "  * 4/8..."
getfile "${URL}lib/send_output.sh"                "${BASEDIR}/lib/send_output.sh"
echo "  * 5/8..."
getfile "${URL}lib/set_commands_to_run.sh"        "${BASEDIR}/lib/set_commands_to_run.sh"
echo "  * 6/8..."
getfile "${URL}lib/set_environment.sh"            "${BASEDIR}/lib/set_environment.sh"
echo "  * 7/8..."
getfile "${URL}lib/set_os.sh"                     "${BASEDIR}/lib/set_os.sh"
echo "  * 8/8..."
getfile "${URL}lib/collect_available_commands.sh" "${BASEDIR}/lib/collect_available_commands.sh"

echo "Downloading agent and support files..."
echo "  * 1/3..."
getfile "${URL}trafikito"       "${BASEDIR}/trafikito"
echo "  * 2/3..."
getfile "${URL}trafikito-agent" "${BASEDIR}/trafikito-agent"
echo "  * 3/3..."
getfile "${URL}reconfigure"     "${BASEDIR}/reconfigure"

chmod +x "${BASEDIR}/trafikito" "${BASEDIR}/trafikito-agent" "${BASEDIR}/reconfigure"
chown -R $RUNAS $BASEDIR

# reconfigure to build executables
${BASEDIR}/reconfigure

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

