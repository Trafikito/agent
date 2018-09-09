###############################################################################
# this will set variables "os", "os_codename", "os_release" and "centos_flavor"
###############################################################################
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
