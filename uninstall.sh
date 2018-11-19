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

WHOAMI=`whoami`

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
echo "This is 2 steps process:"
echo "1. Stop the agent"
echo "2. Delete the files"
echo ""

BASEDIR="${0%/*}"
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

echo -n "1/2: Do you want to STOP the Trafikto agent? (type 'yes' to continue): "; read x
if [ "$x" != 'yes' ]; then
    echo "** Uninstall aborted!"
    exit 0
fi

WHOAMI=`whoami`

# remove startup config
if [ -f $BASEDIR/lib/remove_startup.sh ]; then
    . $BASEDIR/lib/remove_startup.sh
elif [ -f $BASEDIR/trafikito ]; then
    $BASEDIR/trafikito stop
fi

kill $(ps aux | awk '/trafikito_wrapper.sh/ {print $2}') >/dev/null 2>&1

# now remove everything in BASEDIR
echo -n "2/2: Do you want to remove the Trafikto agent files in $BASEDIR? (type 'yes' to continue): "; read x
if [ "$x" != 'yes' ]; then
    echo "** Uninstall aborted!"
    exit 0
fi

rm -rf "$BASEDIR"
if [ $? -ne 0 ]; then
    echo "** Removing $BASEDIR failed! Looks like you don't have write permission"
fi

echo "Trafikito where successfully uninstalled"
