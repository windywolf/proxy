proxy_proxy_server=""
proxy_user_name=""
proxy_password=""
proxy_local_port=""
proxy_remote_port=""
proxy_configured="False"
proxy_execpath=$ZSH_CUSTOM"/plugins/proxy"
proxy_statusfile=${TMPDIR}status.tmp
proxy_pidfile=${TMPDIR}omz_proxy.pid
proxy_mux_uds="${HOME}/.ssh/proxy.sock"

autoload _check_connection
autoload _monitor_connection

# Fetch proxy info from configuration file - proxy.coif
# TODO: Shall we check the content of each variable?
# TODO: Shall we support multiple proxies? And make user be able to switch among all proxies?
function read_proxy_config() {
    if [ ! -e $proxy_execpath/proxy.conf ]; then
        echo "Please config proxy.conf in ${proxy_execpath} first!"
        return 1
    fi

    proxy_proxy_server=`sed -n "s/proxy_server=//p" $proxy_execpath/proxy.conf`
    proxy_user_name=`sed -n "s/user_name=//p" $proxy_execpath/proxy.conf`
    proxy_password=`sed -n "s/password=//p" $proxy_execpath/proxy.conf`
    proxy_local_port=`sed -n "s/local_port=//p" $proxy_execpath/proxy.conf`
    proxy_remote_port=`sed -n "s/remote_port=//p" $proxy_execpath/proxy.conf`

    proxy_configured="True"
}

# Connect to proxy via ssh tunnel
function connect_proxy() {
    # 0. Check if the proxy info's already configured
    if [ $proxy_configured != "True" ]; then
        echo "Please config proxy.conf in ${proxy_execpath} first!"
        return 1
    fi
    # 1. Check if we are already connected to the proxy
    check_connection
    ret=$?
    if [ $ret -eq 127 ]; then
        echo "The proxy server is physically disconnected!"
        return 1
    elif [ $ret -eq 0 ]; then
        # Already connected to proxy
        echo "Already connected to proxy server"
        return 0
    fi
    # 2. Connect to proxy
    echo "Connecting to proxy server.." >/dev/null
    expect $proxy_execpath/connect_to_server.exp $proxy_proxy_server $proxy_user_name $proxy_password $proxy_local_port $proxy_remote_port $proxy_mux_uds >/dev/null & 

    return 0
}

# Disconnect the connection to proxy
function disconnect_proxy() {
    # 0. Check if the proxy info's already configured
    if [ $proxy_configured != "True" ]; then
        echo "Please config proxy.conf in ${proxy_execpath} first!"
        return 1
    fi
    # 1. Check if we are already connected to the proxy
    check_connection
    ret=$?
    if [ $ret -ne 0 ]; then
        echo "The proxy server is already disconnected!"
        return 0
    fi
    # 2. Try to disconnect the connection by killing the background multiplex SSH process
    mux_pid=`ps aux | grep $proxy_mux_uds | grep -v 'grep' | awk '{print $2}'`
    kill $mux_pid
    check_connection
    ret=$?
    if [ $ret -ne 0 ]; then
        echo "The proxy server's disconnected!"
        return 0
    fi
}

# Check if the connection to proxy is still available
function check_connection() {
    _check_connection
    return $?
}

# Start a daemon process to monitor connection
function start_monitor_connection() {
    if [ -e $proxy_pidfile ]; then
        # Find out if there's already a monitor thread available.
        oldpid=`cat $proxy_pidfile` 
        ret=`ps ax -o pid | grep $oldpid | wc -l`
        [ $ret -eq 1 ] && return 0
    fi

    _monitor_connection & bg_pid=$!
    echo $bg_pid > $proxy_pidfile

    return 0
}

# Stop the daemon process
function stop_monitor_connection() {
    if [ -e $proxy_pidfile ]; then
        oldpid=`cat $proxy_pidfile`
        ps ax -o pid,ppid | grep $oldpid | awk '{print $1}' | xargs kill -s INT
        rm -f $proxy_pidfile
    else
        # NO pidfile means no process to kill
        return 1
    fi

    return 0
}

read_proxy_config
start_monitor_connection
