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
echo "    Uninstalling Trafikito agent"
echo ""
echo ""

BASEDIR="${0%/*}"
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

while true; do
    /bin/echo -n "Do you want to uninstall the Trafikto agent and remove $BASEDIR? (yes or no): "; read x
    if [ "$x" = 'yes' ]; then
        break
    fi
    echo "** Uninstall aborted!"
    exit 0
done

WHOAMI=`whoami`

# remove systemd config
if [ -f /etc/systemd/system/trafikito.service ]; then
    if [ $WHOAMI != 'root' ]; then
        echo "The Trafikito agent is controlled by systemd: you need to be root to disable and remove the configuration";
        echo "** Cannot continue!"
        exit 1
    fi
    systemctl disable trafikito
    rm /etc/systemd/system/trafikito.service
fi

# remove upstart config
if [ -f /etc/init/trafikito.conf ]; then
    if [ $WHOAMI != 'root' ]; then
        echo "The Trafikito agent is controlled by upstart: you need to be root to disable and remove the configuration";
        echo "** Cannot continue!"
        exit 1
    fi
    initctl stop trafikito 2>/dev/null
    rm /etc/init/trafikito.conf
fi

# now remove everything in BASEDIR
rm -rf "$BASEDIR"
if [ $? -ne 0 ]; then
    echo "** Removing $BASEDIR failed! Looks like you don't have write permission"
fi

echo "Trafikito where successfully uninstalled"
