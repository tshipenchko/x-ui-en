#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

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

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
  arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
  arch="arm64"
else
  arch="amd64"
  echo -e "${red}Failed to detect the architecture, using the default architecture: ${arch}${plain}"
fi

echo "Architecture: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ] ; then
    echo "This software does not support 32-bit systems (x86), please use 64-bit systems (x86_64), if the detection is incorrect, please contact the author"
    exit 1
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

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar -y
    else
        apt install wget curl tar -y
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/tshipenchko/x-ui-enreleases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Failed to detect the x-ui version. It may be that the Github API limit is exceeded. Please try again later, or manually specify the x-ui version to install.${plain}"
            exit 1
        fi
        echo -e "The latest version of x-ui is detected：${last_version}，installation is started"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/tshipenchko/x-ui-enreleases/download/${last_version}/x-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Downloading x-ui failed, please make sure your server can download files from the Github${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/tshipenchko/x-ui-enreleases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        echo -e "Installing x-ui v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Failed to download x-ui v$1, please make sure this version exists${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/tshipenchko/x-ui-en/master/x-ui.sh
    chmod +x /usr/bin/x-ui
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui v${last_version}${plain} 安装完成，面板已启动，"
    echo -e ""
    echo -e "If it is a clear installation, the default web port is ${green}54321${plain} username and password are both by default ${green}admin${plain}"
    echo -e "Please make sure that this port is not occupied by other programs，${yellow}and make sure that port 54321 is released${plain}"
    echo -e ""
    echo -e "If it is to update the panel, then access the panel as you did before"
    echo -e ""
    echo -e "x-ui usage: "
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

echo -e "${green}Installing...${plain}"
install_base
install_x-ui $1
