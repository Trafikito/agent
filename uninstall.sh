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

ECHO=/bin/echo
WHOAMI=`whoami`

$ECHO ""
$ECHO ""
$ECHO "  _____           __ _ _    _ _"
$ECHO " |_   _| __ __ _ / _(_) | _(_) |_ ___"
$ECHO "   | || '__/ _\` | |_| | |/ / | __/ _ \\"
$ECHO "   | || | | (_| |  _| |   <| | || (_) |"
$ECHO "   |_||_|  \__,_|_| |_|_|\_\_|\__\___/"
$ECHO ""
$ECHO ""
$ECHO "    Uninstalling Trafikito agent"
$ECHO ""
$ECHO ""
$ECHO "This is 2 steps process:"
$ECHO "1. Stop the agent"
$ECHO "2. Delete the files"
$ECHO ""

BASEDIR="${0%/*}"
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

while true; do
    $ECHO -n "1/2: Do you want to STOP the Trafikto agent? (type 'yes' to continue): "; read x
    if [ "$x" = 'yes' ]; then
        break
    fi
    $ECHO "** Uninstall aborted!"
    exit 0
done

WHOAMI=`whoami`

# remove startup config
if [ -f $BASEDIR/lib/remove_startup.sh ]; then
    . $BASEDIR/lib/remove_startup.sh
fi

# now remove everything in BASEDIR
rm -rf "$BASEDIR"
if [ $? -ne 0 ]; then
    $ECHO "** Removing $BASEDIR failed! Looks like you don't have write permission"
fi

$ECHO "Trafikito where successfully uninstalled"
