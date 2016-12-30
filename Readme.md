A proxy plugin for Oh-My-Zsh, ONLY works for MAC now.
(Please let me know if you want Linux support)

How to set up:
0. Here's what you need to prepare before setting up:
    0.1 A host with Internet access & SSH Server(22/tcp);
    0.2 A mac with ZSH & Oh-My-Zsh installed;
1. Clone the repo to $ZSH_CUSTOM/plugins;
2. Create a 'proxy.conf' based on the 'proxy.conf.example';
3. Add proxy to plugins in $HOME/.zshrc
4. cp the agnoster_proxy.zsh-theme to $ZSH_CUSTOM/themes
5. Enjoy!

How to use:
1. connect_proxy => Connect to the proxy server;
2. check_connection => Check if the proxy server's connected, the result can be displayed in theme's prompt;
3. start_monitor_connection => Start a background process to monitor the connection, this function can be started automatically when the plugin's loaded;
4. stop_monitor_connection => Stop the background process;
