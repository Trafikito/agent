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

export URL_OUTPUT="https://api.trafikito.com/v2/agent/output"
export URL_GET_CONFIG="https://api.trafikito.com/v2/agent/get"
export URL_DOWNLOAD=${URL_DOWNLOAD:-"https://api.trafikito.com/v1/agent/get_agent_file?file="}  # override from environment for testing
export URL_DOWNLOAD=http://tui.home/trafikito/

# function to prompt for yn: echo is a shell builtin and the -n option should work in any POSIX shell
fn_prompt() {
    default=$1
    mesg=$2
    # if not running with a tty returns $default
    if [ ! "`tty`" ]; then
        return 1
    fi
    while true; do
        echo -n $mesg; read x
        if [ -z "$x" ]; then
            answer=$default
        else
            case "$x" in 
                y*|Y*) answer=Y ;;
                n*|N*) answer=N ;;
                *) echo "Please reply y or n"
                continue
            esac
        fi
        if [ $answer = $default ]; then
            return 1
        else
            return 0
        fi
    done
}

usage() {
    (
    echo
    echo "Usage: sh $0 --api_key=<api_key> --workspace_id=<workspace_id> [-name=<default name>]"
    echo
    echo "To install Trafikito agent you need to get server api key, workspace id, and (optional)"
    echo "default name."
    echo
    echo "To get all the details please follow these steps:"
    echo "  1. Visit https://trafikito.com/servers"
    echo "  2. Find your server on servers list or add new one"
    echo "  3. Click 3 dots button to open menu and select: How to install?"
    echo "  4. Use this command (replace <api_key> and <server_id> with correct values):"
    echo "     sh $0 --api_key=<api_key> --workspace_id=<workspace_id> [-name=<default name>]"
    ) 1>&2
    exit 1
}

# parse arguments
#for x in $*; do
#    option=`echo $x | sed -e 's#=.*##'`
#    arg=`echo $x | sed -e 's#.*=##'`
#    case "$option" in
#        --api_key) API_KEY=$arg ;;
#        --workspace_id) WORKSPACE_ID=$arg ;;
#        --name) HOSTNAME=$arg ;;
#        *) echo "Bad option '$option'" 1>&2
#           usage
#    esac
#done

#test -z "$API_KEY"      && echo "Option '--api_key' with an argument is required" 1>&2 && usage
#test -z "$WORKSPACE_ID" && echo "Option '--workspace_id' with an argument is required" 1>&2 && usage
HOSTNAME=${HOSTNAME:-`hostname -f`}

echo "'$API_KEY' '$WORKSPACE_ID' '$HOSTNAME'"

# TODO testing
API_KEY=$1
SERVER_ID=$2

# running as root or user ?
# LUKAS: we can check if sudo is installed, but: we do not know if the user can sudo
# su will always be installed, but to use 'su -c "sh $0"' will only work if
# the user has root's password - another unknown
# keep it like this?
RUNAS="nobody"
WHOAMI=`whoami`
if [ "$WHOAMI" != "root" ]; then
    echo "If possible, run installation as root user."
    echo "Root user is used to make script running as 'nobody' which improves security."
    echo "To install as root either log in as root and execute the script or use:"
    echo 
    echo "  sudo sh $0"
    echo
    fn_prompt "N" "Continue as $WHOAMI [yN]: " || exit 1
    RUNAS=$WHOAMI
fi

# get BASEDIR
export BASEDIR="/opt/trafikito"
while true; do
    fn_prompt "Y" "Going to install Trafikito in $BASEDIR [Yn]: "
    if [ $? -eq 0 ]; then
        echo -n "  Enter directory for installation: "; read BASEDIR
        continue
    fi
    if [ -d $BASEDIR ]; then
        fn_prompt "Y" "  Found existing $BASEDIR: okay to remove it? [Yn]: "
        if [ $? -eq 1 ]; then
            reason=`rm -rf $BASEDIR 2>&1`
            if [ $? -ne 0 ]; then
                echo "  Remove failed: $reason - please try again"
                continue
            fi
        else
            continue
        fi
    fi
    break
done

mkdir -p $BASEDIR 2>/dev/null
if [ $? -ne 0 ]; then
    fn_prompt "Y" "Found existing $BASEDIR: okay to remove it? [Yn]: "
    rm -rf $BASEDIR
    mkdir -p $BASEDIR || exit 1
fi

# create std subdirs
mkdir $BASEDIR/etc
mkdir $BASEDIR/lib
mkdir $BASEDIR/var

# build config and source it
CONFIG="$BASEDIR/etc/trafikito.cfg"
cat >$CONFIG <<STOP
export RUNAS=$RUNAS
export API_KEY=$API_KEY
export SERVER_ID=$SERVER_ID
export TMP_FILE=$BASEDIR/var/trafikito.tmp
STOP
. $BASEDIR/etc/trafikito.cfg

# function to install a tool
fn_install_tool() {
    tool=$1
    help=$2
    pkg=$tool  # in case $tool is in a package
    echo -n "  $tool - $help: "

    # check if command is installed
    x=`which $tool`
    if [ -z "$x" ]; then
        echo "not found - going to install it"
    else
        echo "found $x"
        return 0
    fi

    if [ $WHOAMI != 'root' ]; then
        echo -n "  Need root privilege to install '$pkg': please install it manually [enter]: "; read x
        return
    fi

    fn_prompt "Y" "  Install package $pkg [Yn]: "
    if [ $? -eq 0 ]; then
        return 1
    fi
    if [ -x /usr/bin/apt-get ]; then # Debian
        /usr/bin/apt-get -y install $pkg
    elif [ -x /usr/bin/yum ]; then # RedHat
        /usr/bin/yum -y install $pkg
    elif [ -x /sbin/apk ]; then # alpine
        /sbin/apk --no-cache add $pkg
    else
        echo "  ERROR: this system's package manager is not supported"
        echo "    Please contact trafikito support for help"  # TODO
        return 1
    fi
    if [ $? ]; then
        echo "  Something went wrong: please contact trafikito support for help"  # TODO
        return 1
    else
        echo "  installed `which $tool`"
        return 0
    fi
}

# install curl
echo -n "Checking for curl..."
fn_install_tool "curl" "transfer an url"
if [ $? -ne 0 ]; then
    echo "  Looks like your distro does not have curl: please contact trafikito support"
    exit 1
fi

echo "* Looking for required commands..."
fn_install_tool "tree"   "test command not used in trafikito"
fn_install_tool "df"     "report file system disk space usage"
fn_install_tool "free"   "report amount of free and used memory in the system"
fn_install_tool "egrep"  "print lines matching a pattern"
fn_install_tool "pgrep"  "look up or signal processes based on name and other attributes"
fn_install_tool "lsof"   "list open files"
fn_install_tool "sed"    "stream editor for filtering and transforming text"
fn_install_tool "su"     "change user ID or become superuser"
fn_install_tool "top"    "display processes"
fn_install_tool "uptime" "tell how long the system has been running"
fn_install_tool "vmstat" "report virtual memory statistics"


echo "* Installing agent..."
curl -X POST --retry 3 --retry-delay 1 --max-time 30 \
     -o "${BASEDIR}/trafikito"                "${URL_DOWNLOAD}/trafikito" \
     -o "${BASEDIR}/uninstall.sh"             "${URL_DOWNLOAD}/uninstall.sh" \
     -o "${BASEDIR}/lib/trafikito-wrapper.sh" "${URL_DOWNLOAD}lib/trafikito-wrapper.sh" \
     -o "${BASEDIR}/lib/trafikito-agent.sh"   "${URL_DOWNLOAD}lib/trafikito-agent.sh" \
     -o "${BASEDIR}/lib/set_os.sh"            "${URL_DOWNLOAD}lib/set_os.sh"
echo

chmod +x $BASEDIR/trafikito $BASEDIR/lib/*

# build initial settings
echo "* Generating initial settings"
>$TMP_FILE
(
cat <<STOP
trafikito_free="free"
trafikito_cpu_info_full="cat /proc/cpuinfo | sed '/^\s*$/q'"
trafikito_cpu_info="cat /proc/cpuinfo | sed '/^\s*$/q' | egrep -i 'cache\|core\|model\|mhz\|sibling\|vendor\|family'"
trafikito_uptime="uptime"
trafikito_cpu_units_count="cat /proc/cpuinfo 2>&1 | grep processor | wc -l"
trafikito_vmstat="vmstat"
trafikito_df_p="df -P"
trafikito_hostname="hostname"
trafikito_curl="curl --version"
trafikito_df_h="df -h"
trafikito_lsof_count_network_connections="lsof -i | grep -- '->' | wc -l"
trafikito_lsof_count_open_files="lsof | wc -l"
trafikito_netstat_i="netstat -i"
trafikito_vmstat_s="vmstat -s"
trafikito_top="top -bcn1"
STOP
) | while read line; do
    command=`echo $line | sed -e 's#^[^=]*=##' -e 's#^"##' -e 's#"$##'`
    echo "  executing $command..."
    echo "*-*-*-*------------ Trafikito command: $command" >>$TMP_FILE
    eval $command >>$TMP_FILE 2>&1
done

# get os facts
. $BASEDIR/lib/set_os.sh
fn_set_os

# TODO using real $URL_DOWNLOAD here
export URL_DOWNLOAD="https://api.trafikito.com/v1/agent/get_agent_file?file="
echo "* Downloading available_commands.sh (in this file you can find list of commands used at data source settings on UI)"
curl -X POST -H "Content-Type: multipart/form-data" -F "output=@$TMP_FILE" -F "serverId=$SERVER_ID" \
     -F "os=$os" -F "osCodename=$os_codename" -F "osRelease=$os_release" -F "centosFlavor=$centos_flavor" "${URL_DOWNLOAD}available_commands.sh" \
     --retry 3 --retry-delay 1 --max-time 30 -o "${BASEDIR}/available_commands.sh"
curl -s -X POST -F "apiKey=$API_KEY" -F "tmpFile=$TMP_FILE" -F "serverId=$SERVER_ID" "${URL_DOWNLOAD}trafikito.conf" \
     --retry 3 --retry-delay 1 --max-time 30 > "${BASEDIR}/trafikito.conf"

# now everything will be owned by $RUNAS
chown -R $RUNAS $BASEDIR

# configure restart
if [ "$WHOAMI" != "root" ]; then
    echo "Script was not installed as root: cannot configure startup"
    echo "You can control the script manually with:"
    echo
    echo "  $BASEDIR/trafikito {start|stop|restart|status}"
    exit 0
fi

# systemd: test for useable systemctl
x=`which systemctl`
if [ $? -eq 0 ]; then
    echo "You are running systemd..."
    fn_prompt "Y" "Shall I configure, enable and start the agent? [Yn]: "
    if [ $? -eq 1 ]; then
        (
        echo "[Unit]"
        echo "Description=Trafikito Service"
        echo "After=network.target"
        echo "[Service]"
        echo "Type=simple"
        echo "ExecStart=$BASEDIR/lib/trafikito-wrapper.sh $BASEDIR"
        echo "User=nobody"
        echo "Group=nogroup"
        echo "[Install]"
        echo "WantedBy=multi-user.target"
        ) >/etc/systemd/system/trafikito.service
        systemctl enable trafikito
        systemctl start trafikito
        systemctl status trafikito
        exit 0
    fi
fi

