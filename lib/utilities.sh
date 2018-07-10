# function to install a binary (just in case some binaries are in a package)
installBinary() {
    binary=$1
    package=$binary

    if [ `whoami` != 'root' ]; then
        echo "Sorry! Need root privilege to install '$binary'"
        echo "You have to install it manually"
        exit 1
    fi

    echo -n "  Press <enter> to install $package (^C to stop): "; read x
    # Debian
    if [ -x /usr/bin/apt-get ]; then
        /usr/bin/apt-get -y install $package
        return $?
    # Redhat
    elif [ -x /usr/bin/yum ]; then
        /usr/bin/yum -y install $package
        return $?
    # Alpine
    elif [ -x /sbin/apk ]; then
        sbin/apk -y install $package
        return $?
    else
        echo "====================================================="
        echo "ERROR: this system's package manager is not supported"
        echo "Please contact trafikito help!"
        echo "====================================================="
        exit 1
    fi
}

# function to get files using curl
getfile() {
    source_url=$1
    destination=$2
    echo /usr/bin/curl -s -X POST $source_url --retry 3 --retry-delay 1 --max-time 30
    /usr/bin/curl -s -X POST $source_url --retry 3 --retry-delay 1 --max-time 30 >$destination
    # TODO need error handling!
}

