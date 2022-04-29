#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error: ${plain} you must use the root user to run this script！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}The system version is not detected, please contact the script author！${plain}\n" && exit 1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Please use CentOS 7 or later system！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or later system！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or later system！${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [default $2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "The restart of x-ui will also restart xray. Continue?" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Press enter to return to the main menu: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/tshipenchko/x-ui-en/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "This function will force the current latest version to be reinstalled, and the data will not be lost. Continue?" "n"
    if [[ $? != 0 ]]; then
        echo -e "${red}cancelled${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/tshipenchko/x-ui-en/master/install.sh)
    if [[ $? == 0 ]]; then
        echo -e "${green}The update is complete and the panel has been automatically restarted${plain}"
        exit 0
    fi
}

uninstall() {
    confirm "Are you sure you want to uninstall the panel, xray will be also uninstalled?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop x-ui
    systemctl disable x-ui
    rm /etc/systemd/system/x-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/x-ui/ -rf
    rm /usr/local/x-ui/ -rf

    echo ""
    echo -e "The uninstallation was successful, if you want to delete this script, then run it after exiting the script ${green}rm /usr/bin/x-ui -f${plain} delete"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_user() {
    confirm "Are you sure you want to reset your username and password to admin?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -username admin -password admin
    echo -e "The username and password have been reset to ${green}admin${plain}, please restart the panel now"
    confirm_restart
}

reset_config() {
    confirm "Are you sure you want to reset all panel settings? The account data will not be lost, and the username and password will not be changed." "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset
    echo -e "All panel settings have been reset to the default values, now please restart the panel and use the default ${green}54321${plain} port to access the panel"
    confirm_restart
}

set_port() {
    echo && echo -n -e "Enter port [1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        echo -e "${yellow}cancelled${plain}"
        before_show_menu
    else
        /usr/local/x-ui/x-ui setting -port ${port}
        echo -e "After setting up the port, please restart the panel now and use the newly set port ${green}${port}${plain} to access panel"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}The panel is already running and there is no need to start again. If you need to restart, please select restart.${plain}"
    else
        systemctl start x-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}x-ui 启动成功${plain}"
        else
            echo -e "${red}The panel failed to start, probably because the startup time exceeded two seconds, please check the log information later${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        echo -e "${green}The panel has stopped, no need to stop again${plain}"
    else
        systemctl stop x-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            echo -e "${green}x-ui and xray stopped successfully ${plain}"
        else
            echo -e "${red}The panel failed to stop, probably because the stop time exceeded two seconds, please check the log information later${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart x-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}x-ui and xray restarted successfully${plain}"
    else
        echo -e "${red}The panel failed to restart, probably because the startup time exceeded two seconds, please check the log information later${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status x-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable x-ui
    if [[ $? == 0 ]]; then
        echo -e "${green}x-ui set the boot to start successfully${plain}"
    else
        echo -e "${red}x-ui failed to set the boot to self-start${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable x-ui
    if [[ $? == 0 ]]; then
        echo -e "${green}x-ui cancel the boot and start successfully${plain}"
    else
        echo -e "${red}x-ui failed to cancel the boot and self-start${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u x-ui.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

migrate_v2_ui() {
    /usr/local/x-ui/x-ui v2-ui

    before_show_menu
}

install_bbr() {
    # temporary workaround for installing bbr
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    echo ""
    before_show_menu
}

update_shell() {
    wget -O /usr/bin/x-ui -N --no-check-certificate https://github.com/tshipenchko/x-ui-en/raw/master/x-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}The download script failed, please check whether this function is connected to Github${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/x-ui
        echo -e "${green}The upgrade script was successful, please re-run the script${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/x-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status x-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled x-ui)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}The panel is installed, please do not repeat the installation${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}Please install the panel first${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "Panel status: ${green}already running${plain}"
            show_enable_status
            ;;
        1)
            echo -e "Panel status: ${yellow}not running${plain}"
            show_enable_status
            ;;
        2)
            echo -e "Panel status: ${red}not installed${plain}"
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Not installed: ${green}yes${plain}"
    else
        echo -e "Not installed: ${red}no${plain}"
    fi
}

check_xray_status() {
    count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "xray status: ${green}runing${plain}"
    else
        echo -e "xray status: ${red}not running${plain}"
    fi
}

show_usage() {
    echo "x-ui usage: "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - display management menu (more functions)"
    echo -e "x-ui start        - start x-ui"
    echo -e "x-ui stop         - stop x-ui"
    echo -e "x-ui restart      - restart x-ui"
    echo -e "x-ui status       - view x-ui status"
    echo -e "x-ui enable       - enable x-ui service"
    echo -e "x-ui disable      - disable x-ui service"
    echo -e "x-ui log          - view x-ui log"
    echo -e "x-ui v2-ui        - migrate data from v2-ui to x-ui"
    echo -e "x-ui update       - update x-ui"
    echo -e "x-ui install      - install x-ui"
    echo -e "x-ui uninstall    - uninstall x-ui"
    echo -e "----------------------------------------------"
}

show_menu() {
    echo -e "
 ${green}x-ui panel management script${plain}
 ${green}0.${plain} exit script
————————————————
 ${green}1.${plain} install x-ui
 ${green}2.${plain} update x-ui
 ${green}3.${plain} uninstall x-ui
————————————————
 ${green}4.${plain} reset username and password
 ${green}5.${plain} reset panel settings
 ${green}6.${plain} set panel port
————————————————
 ${green}7.${plain} start x-ui
 ${green}8.${plain} stop x-ui
 ${green}9.${plain} restart x-ui
 ${green}10.${plain} view x-ui status
 ${green}11.${plain} view x-ui log
————————————————
 ${green}12.${plain} set x-ui to start automatically
 ${green}13.${plain} cancel x-ui auto-start
————————————————
 ${green}14.${plain} One-click install bbr (latest kernel)
 "
    show_status
    echo && read -p "Choice [0-14]: " num

    case "${num}" in
        0) exit 0
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && update
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && reset_user
        ;;
        5) check_install && reset_config
        ;;
        6) check_install && set_port
        ;;
        7) check_install && start
        ;;
        8) check_install && stop
        ;;
        9) check_install && restart
        ;;
        10) check_install && status
        ;;
        11) check_install && show_log
        ;;
        12) check_install && enable
        ;;
        13) check_install && disable
        ;;
        14) install_bbr
        ;;
        *) echo -e "${red}Please enter the correct number [0-14]${plain}"
        ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0
        ;;
        "stop") check_install 0 && stop 0
        ;;
        "restart") check_install 0 && restart 0
        ;;
        "status") check_install 0 && status 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0
        ;;
        "v2-ui") check_install 0 && migrate_v2_ui 0
        ;;
        "update") check_install 0 && update 0
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        *) show_usage
    esac
else
    show_menu
fi
