proxy_config="default"
proxy_proxy_server=""
proxy_user_name=""
proxy_password=""
proxy_local_port=""
proxy_remote_port=""
proxy_configured="False"
proxy_execpath=$ZSH_CUSTOM"/plugins/proxy"
proxy_statusfile=${TMPDIR}status.tmp
proxy_cur_config=${TMPDIR}proxy_cur_config.tmp
proxy_pidfile=${TMPDIR}omz_proxy.pid
proxy_mux_uds="${HOME}/.ssh/proxy.sock"

autoload _check_connection
autoload _monitor_connection

# Fetch proxy info from configuration file - proxy.conf
# TODO: Shall we check the content of each variable?
function read_proxy_config() {
    if [ ! -e $proxy_execpath/proxy.conf ]; then
        echo "Please config proxy.conf in ${proxy_execpath} first!"
        return 1
    fi
    [ $proxy_configured = "True" ] && return 0

    # 0 Check if the section exists in config file.
    [ $1 ] && proxy_config=$1
    grep $proxy_config $proxy_execpath/proxy.conf >/dev/null
    if [ $? -ne 0 ]; then
        echo "Proxy config file error!"
        proxy_configured="False"
        proxy_config="default"
        return 127
    fi
    # 1. Set sed's range due to config_sec variable.
    config="/$proxy_config/,/^\[/"

    proxy_proxy_server=`sed -n "${config}s/proxy_server=//p" $proxy_execpath/proxy.conf`
    proxy_user_name=`sed -n "${config}s/user_name=//p" $proxy_execpath/proxy.conf`
    proxy_password=`sed -n "${config}s/password=//p" $proxy_execpath/proxy.conf`
    proxy_local_port=`sed -n "${config}s/local_port=//p" $proxy_execpath/proxy.conf`
    proxy_remote_port=`sed -n "${config}s/remote_port=//p" $proxy_execpath/proxy.conf`

    proxy_configured="True"
    echo $proxy_config > $proxy_cur_config
}

# Connect to proxy via ssh tunnel
function connect_proxy() {
    # 0. Check if the proxy info's already configured
    if [ $proxy_configured != "True" ]; then
        echo "Please config proxy.conf in ${proxy_execpath} first!"
        return 1
    fi
    # 1. Re-read configuration from config file
    config="default"
    [ $1 ] && config=$1
    if [ $proxy_config != $config ]; then
        # 1.0 Stop monitor process and disconnect the old connection
        stop_monitor_connection
        disconnect_proxy
        # 1.1 Re-load the configuration
        proxy_configured="False"
        read_proxy_config $config
        if [ $? -ne 0 ]; then
            return 127
        fi
        # 1.2 Re-start monitor process
        start_monitor_connection
    fi

    # 2. Check if we are connecting to the proxy
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
    # 3. Connect to proxy
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
    [ $mux_pid ] && kill $mux_pid
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
    ret=$?
    echo "Proxy:    $proxy_config"
    echo "Address:  $proxy_proxy_server"
    echo "Status:   `cat $proxy_statusfile`"
    return $ret
}

# Start a daemon process to monitor connection
function start_monitor_connection() {
    [ $proxy_configured = "False" ] && return 1
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

# Set up proxy into git configuration.
function set_proxy_for_git() {
    git config --global http.proxy "socks5://localhost:"$proxy_local_port
    git config --global https.proxy "socks5://localhost:"$proxy_local_port
}

# Unset git's proxy configuration
function unset_proxy_for_git() {
    git config --global --unset http.proxy
    git config --global --unset https.proxy
}

if [ -e $proxy_cur_config ]; then
    read_proxy_config `cat $proxy_cur_config`
else
    read_proxy_config
fi
start_monitor_connection
