function set_proxy_vars() {
    export no_proxy="localhost,127.0.0.1,localaddress,.localdomain.com,/var/run/docker.sock,.nokia.net,.alcatel-lucent.com"
    export http_proxy="http://$1/"
    export https_proxy=$http_proxy
    export ftp_proxy=$http_proxy
    export rsync_proxy=$http_proxy

    export NO_PROXY=$no_proxy
    export HTTP_PROXY=$http_proxy
    export HTTPS_PROXY=$http_proxy
    export FTP_PROXY=$http_proxy
    export RSYNC_PROXY=$http_proxy

    echo "Proxy environment variable set."
    return 0
}

function set_proxy_interactive() {
    echo -n "username (leave empty for non-authenticated proxy) : "; read username
    if [[ $username != "" ]]; then
        echo -n "password: "
        read -es password
        local pre="$username:$password@"
    fi

    echo -n "server: "; read server
    echo -n "port: "; read port

    echo "Configuring environment to use proxy $pre$server:$port"
    set_proxy_vars $pre$server:$port
}

function proxy_on() {
    if (( $# > 0 )); then
        # If arguments are given :
        #   - first check if argument is a well known proxy and use pre-configured address
        #   - if not, check if it's a valid proxy address and use it

        # Check if a well known proxy is given
        case $1 in
            corporate)
                proxy="tux-04.net.alcatel.be:8000" ;;
            corporate2)
                proxy="tux-04.net.alcatel.be:1080" ;;
            delorean)
                proxy="delorean.nuagedemo.net:80" ;;
            nokia)
                proxy="135.245.115.123:8000" ;;
            nokia2)
                proxy="proxy.lbs.alcatel-lucent.com:8000" ;;
            #
            # add other cases here for other proxies
            # [...]
            #
            *)
                # This could be improved
                proxy=$(echo $@ | sed -n 's/\([0-9]\{1,3\}.\)\{4\}:\([0-9]\+\)/&/p')
                if [[ $proxy != $@ ]]; then
                    >&2 echo "Invalid address"
                    return 1
                fi
                ;;
        esac
        set_proxy_vars $proxy
    else
        # If not arguments are given, set proxy settings interactively
        set_proxy_interactive
    fi

    set_git_proxy $proxy
}

# See http://gitolite.com/git-over-proxy.html
function set_git_proxy() {
    local proxy=${1}
    local git_proxy_wrapper=/tmp/git_proxy_wrapper.sh
    local git_ssh_proxy_wrapper=/tmp/git_ssh_proxy_wrapper.sh

    # Proxy  the git protocol
    rm -f ${git_proxy_wrapper}
    cat > ${git_proxy_wrapper} << EOF
#!/bin/sh
set -x
socat - PROXY:${proxy%:*}:\$1:\$2,proxyport=${proxy#*:}
EOF
    chmod u+x ${git_proxy_wrapper}
    export GIT_PROXY_COMMAND=${git_proxy_wrapper}

    # Proxy for the SSH protocol
    rm -f ${git_ssh_proxy_wrapper}
    cat > ${git_ssh_proxy_wrapper} << EOF
#!/bin/sh
set -x
ssh -o ProxyCommand='socat - PROXY:${proxy%:*}:%h:%p,proxyport=${proxy#*:}' "\$@"
EOF
    chmod u+x ${git_ssh_proxy_wrapper}
    export GIT_SSH=${git_proxy_wrapper}

    # Since git 2.3 we can use the GIT_SSH_COMMAND instead. It takes precedence over GIT_SSH.
    # See https://stackoverflow.com/a/28527476/1836144
    GIT_SSH_COMMAND="ssh -o Proxycommand='socat - PROXY:${proxy%:*}:%h:%p,proxyport=${proxy#*:}'"
    export GIT_SSH_COMMAND
}

# function use_git_proxy() {
#     local proxy=${1}
#     local bin=${HOME}/.bin
#     local git_proxy_wrapper=${bin}/git_proxy_wrapper.sh
#     local git_ssh_proxy_wrapper=${bin}/git_ssh_proxy_wrapper.sh
# 
#     rm -f ${git_proxy_wrapper}
#     cat > ${git_proxy_wrapper} << EOF 
# #!/bin/sh
# set -x
# nc -x ${proxy} -X connect \$*
# EOF
#     chmod u+x ${git_proxy_wrapper}
#     export GIT_PROXY_COMMAND=${git_proxy_wrapper}
# 
#     rm -f ${git_ssh_proxy_wrapper}
#     cat > ${git_ssh_proxy_wrapper} << EOF 
# #!/bin/sh
# set -x
# ssh -o ProxyCommand='nc -X connect -x ${proxy} %h %p' "\$@"
# EOF
#     chmod u+x ${git_ssh_proxy_wrapper}
#     export GIT_SSH=${git_proxy_wrapper}
# }

function proxy_off(){
    unset http_proxy  ; unset HTTP_PROXY
    unset https_proxy ; unset HTTPS_PROXY
    unset ftp_proxy   ; unset FTP_PROXY
    unset rsync_proxy ; unset RSYNC_PROXY
    echo -e "Proxy environment variable removed."
}
