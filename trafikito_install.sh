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
echo "    Trafikito agent installation"
echo ""
echo ""

export PATH=/usr/sbin:/usr/bin:/sbin:/bin

# use printf (a shell builtin) here because echo is *very* distro dependant
fn_prompt() {
    default=$1
    mesg=$2
    # if not running with a tty returns $default
    if [ ! "`tty`" ]; then
        return 1
    fi
    while true; do
        printf "$mesg "; read x
        if [ -z "$x" ]; then
            answer="$default"
        else
            case "$x" in
                y*|Y*) answer=Y ;;
                n*|N*) answer=N ;;
                *) echo "Please reply y or n"
                continue
            esac
        fi
        if [ "$answer" = "$default" ]; then
            return 1
        else
            return 0
        fi
    done
}

usage() {
    (
    echo
    echo "Usage: sh $0 --user_api_key=<api_key> --workspace_id=<workspace_id> [--servername=<servername>]"
    echo
    echo "To install Trafikito agent, please follow these steps:"
    echo "  1. Visit https://trafikito.com/servers"
    echo "  2. Find your server on servers list or add new one"
    echo "  3. Click 3 dots button to open menu and select: How to install?"
    echo "  4. Follow instructions on the dashboard"
    ) 1>&2
    exit 1
}

# parse arguments
for x in $*; do
    option=`echo "$x" | sed -e 's#=.*##'`
    arg=`echo "$x" | sed -e 's#.*=##'`
    case "$option" in
        --user_api_key) USER_API_KEY="$arg" ;;
        --workspace_id) WORKSPACE_ID="$arg" ;;
        --servername)   SERVER_NAME="$arg" ;;
        *) echo "Bad option '$option'" 1>&2
           usage
    esac
done

test -z "$USER_API_KEY" && echo "Option '--user_api_key' with an argument is required" 1>&2 && usage
test -z "$WORKSPACE_ID" && echo "Option '--workspace_id' with an argument is required" 1>&2 && usage
if [ -z "$SERVER_NAME" ]; then
    SERVER_NAME=`hostname -f`
    "echo" -n "Name this Trafikito instance [${SERVER_NAME}]: "; read x
    if [ "$x" ]; then
        SERVER_NAME="$x"
    fi
fi

# running as root or user ?
RUNAS=`whoami`
WHOAMI=`whoami`
if [ "$WHOAMI" != "root" ]; then
    echo "If possible, run installation as root user."
    echo "To install as root either log in as root and execute the script or use:"
    echo
    echo "  sudo sh $0 --user_api_key=$USER_API_KEY --workspace_id=$WORKSPACE_ID --servername=$SERVER_NAME"
    echo
    fn_prompt "N" "Continue as $WHOAMI [yN]: " || exit 1
    RUNAS="$WHOAMI"
fi

# get BASEDIR
export BASEDIR="/opt/trafikito"
while true; do
    fn_prompt "Y" "Going to install Trafikito in $BASEDIR [Yn]: "
    if [ $? -eq 0 ]; then
        printf "  Enter directory for installation: "; read BASEDIR
        # test for starting /
        echo $BASEDIR | grep -q '^\/'
        if [ $? -ne 0 ]; then
            echo "    Directory for installation must be an absolute path!"
            BASEDIR="/opt/trafikito"
            continue
        fi
        # test for spaces in path
        echo $BASEDIR | grep -vq ' '
        if [ $? -ne 0 ]; then
            echo "    Directory name for installation must not contain spaces!"
            BASEDIR="/opt/trafikito"
            continue
        fi
    fi
    if [ -d $BASEDIR ]; then
        fn_prompt "Y" "  Found existing $BASEDIR: okay to remove it? [Yn]: "
        if [ $? -eq 1 ]; then
            if [ -f $BASEDIR/lib/remove_startup.sh ]; then
                . $BASEDIR/lib/remove_startup.sh
            fi
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
mkdir -p $BASEDIR/etc
mkdir -p $BASEDIR/lib
mkdir -p $BASEDIR/var

# build config and source it
CONFIG=$BASEDIR/etc/trafikito.cfg
(
echo export RUNAS=\"$RUNAS\"
echo export USER_API_KEY=\"$USER_API_KEY\"
echo export WORKSPACE_ID=\"$WORKSPACE_ID\"
echo export SERVER_NAME=\"$SERVER_NAME\"
echo export TMP_FILE=\"$BASEDIR/var/trafikito.tmp\"
) >$CONFIG

. $CONFIG

# function to install tools
fn_install_tools() {
    TOOLS=$*
    if [ `which apt-get` ]; then # Debian
        apt-get install $TOOLS
    elif [ `which yum` ]; then # RedHat
        yum -y install $TOOLS
    elif [ `which apk` ]; then # alpine
        apk --no-cache add $TOOLS
    elif [ `which pacman` ]; then # arch
        pacman -S add $TOOLS
    elif [ `which zypper` ]; then # SuSE
        zypper install $TOOLS
    else
        echo "  ERROR: your system's package manager is not supported"
        echo "    Supported package managers: apt-get, yum, apk, pacman, zypper"
        return 1
    fi
}
echo "* Looking for required commands..."
TOOLS=''
set "curl"   "transfer an url (essential)"\
    "df"     "report file system disk space usage"\
    "free"   "report amount of free and used memory in the system"\
    "egrep"  "print lines matching a pattern"\
    "pgrep"  "look up or signal processes based on name and other attributes"\
    "sed"    "stream editor for filtering and transforming text"\
    "su"     "change user ID or become superuser"\
    "top"    "display processes"\
    "uptime" "tell how long the system has been running"\
    "vmstat" "report virtual memory statistics"
while [ $# -ne 0 ]; do
    tool=$1
    help=$2
    shift 2
    printf "  $tool: $help..."
    x=`which $tool` 2>/dev/null
    if [ -z $x ]; then
        TOOLS="$TOOLS$tool "
        echo NOT FOUND
    else
        echo found $x
    fi
done

if [ -z $TOOLS ]; then
    echo
    echo "  Found all required commands"
else
    if [ $WHOAMI = 'root' ]; then
        fn_prompt "Y" "Shall I install missing tools? [Yn]: "
        if [ $? -eq 1 ]; then
            fn_install_tools $TOOLS
        else
            echo
            echo "  Please install the following tools as root: $TOOLS"
        fi
    else
        echo
        echo "  Please install the following tools as root: $TOOLS"
    fi
fi
echo
echo "* Installing agent..."

# select which edge to use and which use as a fallback
API_EDGE="https://api.trafikito.com";

fn_select_edge ()
{
    API_EDGE_1="https://ap-southeast-1.api.trafikito.com"
    API_EDGE_2="https://eu-west-1.api.trafikito.com"
    API_EDGE_3="https://us-east-1.api.trafikito.com"

    # big range to avoid unequal random value distribution on some systems
    DEFAULT_EDGE=`awk 'BEGIN{srand();print int(rand()*(12000-1))+1 }'`
    if [ "$DEFAULT_EDGE" -gt 4000 ]; then
        API_EDGE_1="https://eu-west-1.api.trafikito.com"
        API_EDGE_2="https://us-east-1.api.trafikito.com"
        API_EDGE_3="https://ap-southeast-1.api.trafikito.com"
    fi

    if [ "$DEFAULT_EDGE" -gt 8000 ]; then
        API_EDGE_1="https://us-east-1.api.trafikito.com"
        API_EDGE_2="https://ap-southeast-1.api.trafikito.com"
        API_EDGE_3="https://eu-west-1.api.trafikito.com"
    fi

    testData=`curl -X POST --silent --retry 3 --retry-delay 1 --max-time 30 -H 'Cache-Control: no-cache' -H 'Content-Type: text/plain' "$API_EDGE_1/v2/ping"`
    if [ "$testData" = "OK" ]; then
        API_EDGE="$API_EDGE_1"
    else
      testData=`curl -X POST --silent --retry 3 --retry-delay 1 --max-time 30 -H 'Cache-Control: no-cache' -H 'Content-Type: text/plain' "$API_EDGE_2/v2/ping"`
        if [ "$testData" = "OK" ]; then
            API_EDGE="$API_EDGE_2"
        else
          testData=`curl -X POST --silent --retry 3 --retry-delay 1 --max-time 30 -H 'Cache-Control: no-cache' -H 'Content-Type: text/plain' "$API_EDGE_3/v2/ping"`
          if [ "$testData" = "OK" ]; then
              API_EDGE="$API_EDGE_3"
          else
            echo "Network issues? Try again."
          fi
        fi
    fi
}

fn_select_edge

echo "Edge selected: $API_EDGE"

fn_download ()
{
    count=$1
    file=$2

    url="$API_EDGE/v2/agent/get_agent_file?file=$file"
    curl -X POST --silent --retry 3 --retry-delay 1 --max-time 30 --output "$BASEDIR/$file" -H 'Cache-Control: no-cache' -H 'Content-Type: text/plain' "$url" > /dev/null
    if [ ! -f "$BASEDIR/$file" ]; then
        echo "*** $count/5 Failed to download. Retrying."
        curl -X POST --silent --retry 3 --retry-delay 1 --max-time 60 --output "$BASEDIR/$file" -H 'Cache-Control: no-cache' -H 'Content-Type: text/plain' "$url" > /dev/null
        if [ ! -f "$BASEDIR/$file" ]; then
            echo "*** $count/5 Failed to download. Retrying."
            curl -X POST --silent --retry 3 --retry-delay 1 --max-time 60 --output "$BASEDIR/$file" -H 'Cache-Control: no-cache' -H 'Content-Type: text/plain' "$url" > /dev/null
            if [ ! -f "$BASEDIR/$file" ]; then
                echo "*** $count/5 Failed to download: $file"
                exit 1;
            fi
        fi
    else
        echo "*** $count/5 done"
    fi
}

echo "*** Starting to download agent files"
# during download - set which edge to use for future requests during installation
fn_download 1 trafikito
fn_download 2 uninstall.sh
fn_download 3 lib/trafikito_wrapper.sh
fn_download 4 lib/trafikito_agent.sh
fn_download 5 lib/set_os.sh

echo
chmod +x $BASEDIR/trafikito $BASEDIR/uninstall.sh $BASEDIR/lib/*

# get os facts
. $BASEDIR/lib/set_os.sh
fn_set_os

echo "* Create server and get config file"
curl -X POST --silent --retry 3 --retry-delay 1 --max-time 30 "$API_EDGE/v2/agent/get_agent_file?file=trafikito.conf" \
    -H 'Cache-Control: no-cache' \
    -H 'Content-Type: application/json' \
    -d "{ \
        \"workspaceId\"  : \"$WORKSPACE_ID\", \
        \"userApiKey\": \"$USER_API_KEY\", \
        \"serverName\": \"$SERVER_NAME\", \
        \"tmpFilePath\": \"$TMP_FILE\" \
        }" >$TMP_FILE

grep -q server_id $TMP_FILE
if [ $? -ne 0 ]; then
    cat $TMP_FILE
    echo
    echo "Can not get configuration file. Network issue? Please try again."
    exit 1
fi

export SERVER_ID=`grep server_id $TMP_FILE | sed -e 's/.*= //'`
export API_KEY=`grep api_key   $TMP_FILE | sed -e 's/.*= //'`
echo export SERVER_ID=$SERVER_ID >>$CONFIG
echo export API_KEY=$API_KEY     >>$CONFIG

echo "* Generating initial settings"
>$TMP_FILE
(
cat <<STOP
trafikito_free="free"
trafikito_cpu_info_full="cat /proc/cpuinfo | sed '/^\s*$/q'"
trafikito_cpu_info="cat /proc/cpuinfo | sed '/^\s*$/q' | grep -i 'cache\|core\|model\|mhz\|sibling\|vendor\|family'"
trafikito_uptime="uptime"
trafikito_cpu_processors_count="cat /proc/cpuinfo 2>&1 | grep processor | wc -l"
trafikito_vmstat="vmstat"
trafikito_df_p="df -P"
trafikito_hostname="hostname"
trafikito_hostname_full="hostname -f"
trafikito_df_h="df -h"
trafikito_lsof_count_network_connections="lsof -i | grep -- '->' | wc -l"
trafikito_lsof_count_open_files="lsof | wc -l"
trafikito_netstat_i="netstat -i"
trafikito_vmstat_s="vmstat -s"
trafikito_top="top -bcn1 -o %MEM | sed -e '1,/^\s*$/ d' | head -n 7"
trafikito_ps="ps aux --sort=-%mem,-%cpu --width 200 | head -n 7"
STOP
) | while read line; do
    command=`echo "$line" | sed -e 's#^[^=]*=##' -e 's#^"##' -e 's#"$##'` > /dev/null 2>&1
    echo "  executing $command..."
    echo "*-*-*-*------------ Trafikito command: $command" >>$TMP_FILE
    eval "$command" >>$TMP_FILE 2>&1
done

echo "* Getting available commands file & setting default dashboard"
curl --request POST --silent --retry 3 --retry-delay 1 --max-time 30 \
     --url    "$API_EDGE/v2/agent/get_agent_file?file=available_commands.sh" \
     --header "content-type: multipart/form-data" \
     --form   "output=@$TMP_FILE" \
     --form   "userApiKey=$USER_API_KEY" \
     --form   "workspaceId=$WORKSPACE_ID" \
     --form   "serverId=$SERVER_ID" \
     --form   "os=$os" \
     --form   "osCodename=$os_codename" \
     --form   "osRelease=$os_release" \
     --form   "centosFlavor=$centos_flavor" \
     --output "$BASEDIR/available_commands.sh"
echo
echo "  done"
echo
# now everything will be owned by $RUNAS
chown -R "$RUNAS" $BASEDIR

# configure restart
if [ "$WHOAMI" != "root" ]; then
    echo "Script was not installed as root: cannot configure startup"
    echo "You can control the script manually with:"
    echo
    echo
    echo
    echo "Manual control with:"
    echo "  $BASEDIR/trafikito {start|stop|restart|status}"
    echo
    echo "Uninstall with:"
    echo "  sh $BASEDIR/uninstall"
    echo
    exit 0
fi

# kill any running instances
kill $(ps aux | awk '/trafikito_wrapper.sh/ {print $2}') >/dev/null 2>&1

#####################################
# systemd: test for useable systemctl
#####################################
x=`which systemctl 2>/dev/null`
if [ $? -eq 0 ]; then
    echo "You are running systemd..."
    echo "Configuring, enabling and starting the agent service..."
    (
    echo "[Unit]"
    echo "Description=Trafikito Agent"
    echo "After=network.target"
    echo "[Service]"
    echo "Type=simple"
    echo "ExecStart=$BASEDIR/lib/trafikito_wrapper.sh $SERVER_ID $BASEDIR"
    echo "[Install]"
    echo "WantedBy=multi-user.target"
    ) >/etc/systemd/system/trafikito.service
    (
    echo "echo Disabling and removing systemd"
    echo "systemctl stop trafikito"
    echo "systemctl disable trafikito"
    echo "rm -f /etc/systemd/system/trafikito.service"
    ) >$BASEDIR/lib/remove_startup.sh
    chown $RUNAS $BASEDIR/lib/remove_startup.sh
    systemctl enable trafikito
    systemctl start trafikito
    systemctl status trafikito --no-pager

    # remove script to manually control trafikito
    # rm $BASEDIR/trafikito
    echo
    echo "Done. You will see data at dashboard after a minute."
    echo
    echo
    echo
    echo "Manual control with:"
    echo "  $BASEDIR/trafikito {start|stop|restart|status}"
    echo
    echo "Uninstall with:"
    echo "  sh $BASEDIR/uninstall"
    echo

    exit 0
fi

#################################################################
# System V startup
#################################################################
control=`which update-rc.d 2>/dev/null`    # debian/ubuntu
if [ $? -ne 0 ]; then
    control=`which chkconfig 2>/dev/null`  # mostly everything else
fi
if [ ! -z "$control" ]; then
    echo "System V using $control is available on this server..."
    echo "Configuring, enabling and starting the agent service..."
    (
    echo "#!/bin/sh"
    echo "#"
    echo "# chkconfig: 345 56 50"
    echo "#"
    echo "### BEGIN INIT INFO"
    echo "# Provides:          trafikito"
    echo "# Required-Start:"
    echo "# Required-Stop:"
    echo "# Should-Start:"
    echo "# Should-Stop:"
    echo "# Default-Start:"
    echo "# Default-Stop:"
    echo "# Short-Description: Starts or stops the trafikito agent"
    echo "# Description:       Starts and stops the trafikito agent"
    echo "### END INIT INFO"
    echo
    # remove hash bang and redefine BASEDIR
    grep -v '#!' $BASEDIR/trafikito | sed -e "s#export BASEDIR.*#export BASEDIR=$BASEDIR#"
    ) >/etc/init.d/trafikito
    chmod +x /etc/init.d/trafikito

    case $control in
        *update-rc.d)
            (
            echo "echo Removing System V startup"
            echo "service trafikito stop"
            echo "update-rc.d -f trafikito remove"
            echo "rm -f /etc/init.d/trafikito"
            ) >$BASEDIR/lib/remove_startup.sh
            chown $RUNAS $BASEDIR/lib/remove_startup.sh
            update-rc.d trafikito defaults 99
            update-rc.d trafikito enable
            service trafikito start
            ;;
        *chkconfig)
            (
            echo "echo Removing System V startup"
            echo "service trafikito stop"
            echo "chkconfig --del trafikito"
            echo "rm -f /etc/init.d/trafikito"
            ) > $BASEDIR/lib/remove_startup.sh
            chown $RUNAS $BASEDIR/lib/remove_startup.sh
            chkconfig --add trafikito
            chkconfig trafikito on
            service trafikito start
            ;;
    esac

    # remove script to manually control trafikito
    # rm $BASEDIR/trafikito

    echo
    echo "Done. You will see data at dashboard after a minute."
    echo
    echo
    echo
    echo "Manual control with:"
    echo "  $BASEDIR/trafikito {start|stop|restart|status}"
    echo
    echo "Uninstall with:"
    echo "  sh $BASEDIR/uninstall"
    echo

    exit 0
fi

#################################################################
# openRC: Arch + Gentoo
#################################################################
control=`which rc-update`
if [ ! -z "$control" ]; then
    echo "openRC is available on this server..."
    echo "Configuring, enabling and starting the agent service..."
    (
    # remove hash bang and redefine BASEDIR
    cat $BASEDIR/trafikito | sed -e "s#export BASEDIR.*#export BASEDIR=$BASEDIR#"
    ) >/etc/init.d/trafikito
    chmod +x /etc/init.d/trafikito
    (
    echo "echo Removing openRC startup"
    echo "rc-service trafikito stop"
    echo "rc-update del trafikito"
    echo "rm -f /etc/init.d/trafikito"
    ) >$BASEDIR/lib/remove_startup.sh
    chown $RUNAS $BASEDIR/lib/remove_startup.sh
    rc-update add trafikito
    rc-service trafikito start

    # remove script to manually control trafikito
    # rm $BASEDIR/trafikito

    echo
    echo "Done. You will see data at dashboard after a minute."
    echo
    echo
    echo
    echo "Manual control with:"
    echo "  $BASEDIR/trafikito {start|stop|restart|status}"
    echo
    echo "Uninstall with:"
    echo "  sh $BASEDIR/uninstall"
    echo

    exit 0
fi

echo "Could not determine the startup method on this server"
echo
echo
echo
echo "Manual control with:"
echo "  $BASEDIR/trafikito {start|stop|restart|status}"
echo
echo "Uninstall with:"
echo "  sh $BASEDIR/uninstall"
echo
