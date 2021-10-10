#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

cd "$(
    cd "$(dirname "$0")" || exit
    pwd
)" || exit

#====================================================
#	System Request:Debian 9+/Ubuntu 18.04+/Centos 7+
#	Author:	zhangyu
#	Dscription: ss5 install
#	email:1853479098@qq.com
#====================================================
#fonts color
Green="\033[32m"
Red="\033[31m"
# Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"
source '/etc/os-release'
#notification information
# Info="${Green}[信息]${Font}"
OK="${Green}[OK]${Font}"
error="${Red}[错误]${Font}"
check_system() {
    if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]]; then
        echo -e "${OK} ${GreenBG} 当前系统为 Centos ${VERSION_ID} ${VERSION} ${Font}"
        INS="yum"
	mkdir /etc/yum.repos.d/backup -p
	mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup
        if [[ ${VERSION_ID} == 7 ]]; then
                wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
        else
                wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-8.repo
        fi
	yum clean all && yum makecache
	$INS install qrencode -y
    elif [[ "${ID}" == "debian" && ${VERSION_ID} -ge 8 ]]; then
        echo -e "${OK} ${GreenBG} 当前系统为 Debian ${VERSION_ID} ${VERSION} ${Font}"
        INS="apt"
        $INS update
        $INS install qrencode -y
        ## 添加 apt源
    elif [[ "${ID}" == "ubuntu" && $(echo "${VERSION_ID}" | cut -d '.' -f1) -ge 16 ]]; then
        echo -e "${OK} ${GreenBG} 当前系统为 Ubuntu ${VERSION_ID} ${UBUNTU_CODENAME} ${Font}"
        INS="apt"
        $INS update
        $INS install qrencode -y
    else
        echo -e "${Error} ${RedBG} 当前系统为 ${ID} ${VERSION_ID} 不在支持的系统列表内，安装中断 ${Font}"
        exit 1
    fi

    $INS install dbus lsof -y

    systemctl stop firewalld
    systemctl disable firewalld
    echo -e "${OK} ${GreenBG} firewalld 已关闭 ${Font}"

    systemctl stop ufw
    systemctl disable ufw
    echo -e "${OK} ${GreenBG} ufw 已关闭 ${Font}"
}


is_root() {
    if [ 0 == $UID ]; then
        echo -e "${OK} ${GreenBG} 当前用户是root用户，进入安装流程 ${Font}"
        sleep 3
    else
        echo -e "${Error} ${RedBG} 当前用户不是root用户，请切换到使用 'sudo -i' 切换到root用户后重新执行脚本 ${Font}"
        exit 1
    fi
}




judge() {
    if [[ 0 -eq $? ]]; then
        echo -e "${OK} ${GreenBG} $1 完成 ${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} $1 失败${Font}"
        exit 1
    fi
}

sic_optimization() {
    # 最大文件打开数
    sed -i '/^\*\ *soft\ *nofile\ *[[:digit:]]*/d' /etc/security/limits.conf
    sed -i '/^\*\ *hard\ *nofile\ *[[:digit:]]*/d' /etc/security/limits.conf
    echo '* soft nofile 65536' >>/etc/security/limits.conf
    echo '* hard nofile 65536' >>/etc/security/limits.conf

    # 关闭 Selinux
    if [[ "${ID}" == "centos" ]]; then
        sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
        setenforce 0
    fi

}

port_set() {
        read -rp "请设置连接端口（默认:1080）:" port
        [[ -z ${port} ]] && port="1080"
}

port_exist_check() {
    if [[ 0 -eq $(lsof -i:"${port}" | grep -i -c "listen") ]]; then
        echo -e "${OK} ${GreenBG} $1 端口未被占用 ${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} 检测到 ${port} 端口被占用，以下为 ${port} 端口占用信息 ${Font}"
        lsof -i:"${port}"
        echo -e "${OK} ${GreenBG} 5s 后将尝试自动 kill 占用进程 ${Font}"
        sleep 5
        lsof -i:"${port}" | awk '{print $2}' | grep -v "PID" | xargs kill -9
        echo -e "${OK} ${GreenBG} kill 完成 ${Font}"
        sleep 1
    fi
}
user_set() {
	read -rp "请设置ss5连接账户。默认:admin）:" user
	[[ -z ${user} ]] && user="admin"
	read -rp "请设置ss5连接密码。默认:admin）:" passwd
	[[ -z ${passwd} ]] && passwd="admin"
}


install_ss5() {

    if [[ "${ID}" == "centos" ]]; then
        ${INS} install yum-utils device-mapper-persistent-data lvm2 -y
	yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
	sed -i 's+download.docker.com+mirrors.aliyun.com/docker-ce+' /etc/yum.repos.d/docker-ce.repo
        ${INS} update -y
	${INS} makecache fast
	${INS} install docker-ce  -y
    else
        ${INS} install apt-transport-https ca-certificates curl software-properties-common -y
	curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
	add-apt-repository "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
        ${INS} install docker-ce  -y
    fi
    systemctl restart docker.service
    systemctl enable docker.service
    docker run -d --name ss5 -p ${port}:1080 -e USER=${user} -e PASS=${passwd} --restart=always z4279669/ss5_proxy:latest
    judge "安装 ss5 "


}

connect() {
	IP=$(curl https://api-ipv4.ip.sb/ip)
	echo "IP: $IP"
	echo "端口：$port"
	echo "账户：$user"
	echo "密码：$passwd"
	echo "$IP $port $user $passwd " >/root/ss5.txt
}

weixin() {
	echo -n "wxp://f2f0NRmeKua57Dzo__42775iua3LnpH6286yZ-BJ6mBB1R8" | qrencode -o - -t utf8
}

is_root
check_system
install() {
	sic_optimization
	port_set
	port_exist_check
	user_set
	install_ss5
	connect
}


menu() {
    echo -e "\t ss5 安装管理脚本 "
    echo -e "\t---authored by zhangyu---"
    echo -e "\thttps://www.zhangyu.ml"
    echo -e "\tSystem Request:Debian 9+/Ubuntu 18.04+/Centos 7+"
    echo -e "\t无法使用请联系1853479098@qq.com\n"

    echo -e "—————————————— 安装向导 ——————————————"""
    echo -e "${Green}0.${Font}  微信请我喝奶茶,你的支持是我最大的动力。"
    echo -e "${Green}1.${Font}  安装ss5"
    echo -e "${Green}2.${Font}  退出 \n"




    read -rp "请输入数字：" menu_num
    case $menu_num in
    1)
        install
        ;;
    2)
        exit 0
        ;;
    0)
        weixin
        ;;
    *)
	echo -e "${RedBG}请输入正确的数字${Font}"
        ;;
    esac

}


menu
