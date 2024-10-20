#! /usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

seconfig='/etc/selinux/config'
service='(NetworkManager postfix firewalld)'
interface_name="$(cut -d':' -f2< <(grep -A1 'lo'<<<"$(grep '^[[:digit:]]*:'< <(ip a))" | awk 'NR==2')| tr -d '[:space:]')"
interface_path='/etc/sysconfig/network-scripts'
default_interface_file="$(ls $interface_path/ifcfg-[:lower:]* | xargs -i basename {} | awk 'NR==1')"
interface_name_file_suffix="$(tr -d '[:space:]'< <(echo "${default_interface_file#ifcfg-}"))"

function update_interface(){
    # kvm bridge interface 
    printf '检查网卡配置文件名与网卡是否一致.......'
    if [ "$interface_name_file_suffix" == "$interface_name" ];then
        echo -e "\r\e[70G\e[32;1m[OK]\e[39;0m" 
        printf '检查网卡配置文件.......'
        if (grep -wq "$interface_name" $interface_path/$default_interface_file);then
            sed  -e '/BOOTPROTO/ s:\(.*\):BOOTPROTO=static:g'  -e '/BRIDGE/d' -e '1a BRIDGE=br0' -i $interface_path/$default_interface_file
            echo -e "\r\e[70G\e[32;1m[OK]\e[39;0m" 
        else
            echo -e "\r\e[70G\e[31;1m[ERROR]\e[39;0m"
            printf '修改网卡配置文件中....'
            sed -e "/NAME/ s:\(.*\):NAME=$interface_name:g" -e "/DEVICE/ s:\(.*\):DEVICE=$interface_name:g" -e '/BOOTPROTO/ s:\(.*\):BOOTPROTO=static:g' -e '/BRIDGE/d' -e '1a BRIDGE=br0' -i $interface_path/$default_interface_file
            echo -e "\r\e[70G\e[33;1m[CHANGED]\e[39;0m" 
       fi 
    else
        echo -e "\r\e[70G\e[31;1m[ERROR]\e[39;0m"
        printf '修改网卡文件名.....'
        mv $interface_path/$default_interface_file $interface_path/ifcfg-$interface_name
        echo -e "\r\e[70G\e[33;1m[CHANGED]\e[39;0m" 
        default_interface_file="ifcfg-$interface_name"
        printf '检查网卡配置文件.......'
        if (grep -wq "$interface_name" $interface_path/$default_interface_file);then
            sed  -e '/BOOTPROTO/ s:\(.*\):BOOTPROTO=static:g'  -e '/BRIDGE/d' -e '1a BRIDGE=br0' -i $interface_path/$default_interface_file
            echo -e "\r\e[70G\e[32;1m[OK]\e[39;0m" 
        else
            echo -e "\r\e[70G\e[31;1m[ERROR]\e[39;0m"
            printf '修改网卡配置文件中....'
            sed -e "/NAME/ s:\(.*\):NAME=$interface_name:g" -e "/DEVICE/ s:\(.*\):DEVICE=$interface_name:g" -e '/BOOTPROTO/ s:\(.*\):BOOTPROTO=static:g' -e '/BRIDGE/d' -e '1a BRIDGE=br0' -i $interface_path/$default_interface_file
            echo -e "\r\e[70G\e[33;1m[CHANGED]\e[39;0m" 
       fi 
    fi
    # bridge set
    printf '复制网桥配置文件.....'
    if [ ! -s "$interface_path/ifcfg-br0" ];then
       \cp -af interfaces/ifcfg-br0  $interface_path/ifcfg-br0
       echo -e "\r\e[70G\e[32;1m[OK]\e[39;0m" 
    else 
       echo -e "\r\e[70G\e[33;1m[SKIP]\e[39;0m" 
    fi
    read -p '请输入主机地址【空则使用网卡IP】(eg:192.168.0.5): ' -e IP
    if [ -n "$IP" ];then
        printf '修改网桥IP.....'
        if [[ "$IP" =~ ^(2[0-5][0-5]|[1][0-9][0-9]|[0-9][0-9]?)(\.(2[0-5][0-5]|[1][0-9][0-9]|[0-9][0-9]?)){3}$ ]];then
            sed -i '/IPADDR/d' $interface_path/ifcfg-br0
            sed -i "2i IPADDR=$IP" $interface_path/ifcfg-br0
            echo -e "\r\e[70G\e[32;1m[OK]\e[39;0m" 
        else
            printf "\e[31;1m\e[50G%s %s\e[70G%s\e[39;0m\n" "$IP 不合法" '!!'  '[ERROR]'
            exit 2
        fi
    else
       echo -e "\r\e[70G\e[33;1m网桥IP保存默认设置\e[39;0m"
       IP="$(ip a | grep -e "\b$interface_name\b" -e '\bbr0\b' | grep inet | awk '{print $2}' |cut -d '/' -f1 | tr -d '[:space:]')"
       sed -i '/IPADDR/d' $interface_path/ifcfg-br0
       sed -i "2i IPADDR=$IP" $interface_path/ifcfg-br0
    fi
    read -p '请输入网关【空则使用网卡网关】(eg:192.168.0.100): ' -e Gateway
    if [ -n "$Gateway" ];then
        printf '修改网桥网关.....'
        if [[ "$Gateway" =~ ^(2[0-5][0-5]|[1][0-9][0-9]|[0-9][0-9]?)(\.(2[0-5][0-5]|[1][0-9][0-9]|[0-9][0-9]?)){3}$ ]];then
            sed -i '/GATEWAY/d' $interface_path/ifcfg-br0 
            sed -i "3i GATEWAY=$Gateway" $interface_path/ifcfg-br0
            echo -e "\r\e[70G\e[32;1m[OK]\e[39;0m" 
        else
            printf "\e[31;1m\e[50G%s %s\e[70G%s\e[39;0m\n" "$Gateway 不合法" '!!'  '[ERROR]'
            exit 2
        fi
    else
       echo -e "\r\e[70G\e[33;1m网桥网关保存默认设置\e[39;0m"
       Gateway="$(ip r | awk 'NR==1' | awk '{print $(NF-2)}' | tr -d '[:space:]')"
       sed -i '/GATEWAY/d' $interface_path/ifcfg-br0 
       sed -i "3i GATEWAY=$Gateway" $interface_path/ifcfg-br0
    fi
    read -p '请输入掩码(CIDR)【空则使用网卡掩码】(eg:8/16/24/...): ' -e  -n 2 Prefix 
    if [ -n "$Prefix" ];then
        printf '修改网桥掩码.....'
        if [[ "$Prefix" =~ ^[[:digit:]]{,2}$ ]];then
            sed -i '/PREFIX/d' $interface_path/ifcfg-br0
            sed -i "4i PREFIX=$Prefix" $interface_path/ifcfg-br0
            echo -e "\r\e[70G\e[32;1m[OK]\e[39;0m" 
        else
            printf "\e[31;1m\e[50G%s %s\e[70G%s\e[39;0m\n" "$Prefix 不合法" '!!'  '[ERROR]'
            exit 2
        fi
    else
       echo -e "\r\e[70G\e[33;1m网桥掩码保存默认设置\e[39;0m"
       Prefix="$(ip a | grep -e "\b$interface_name\b" -e '\bbr0\b' | grep inet | awk '{print $2}' | cut -d '/' -f2 | tr -d '[:space:]')"
       sed -i '/PREFIX/d' $interface_path/ifcfg-br0
       sed -i "4i PREFIX=$Prefix" $interface_path/ifcfg-br0
    fi
    systemctl restart network
}

function install_kvm(){
    rm -rf /var/cache/yum
    local count=0
    printf '更新系统全部软件包中.....'
    if [ $count -eq 0 ];then 
       if (yum upgrade -y >& /dev/null);then
           sed -i '/local/ s:count=0:count=1:g' $0
           echo -e "\r\e[70G\e[32;1m[OK]\e[39;0m" 
       fi
    else
       echo -e "\r\e[70G\e[33;1m[SKIP]\e[39;0m"     
    fi
    packages=(qemu-kvm qemu-kvm-tools virt-install qemu-img bridge-utils libvirt virt-manager kvm)
    index=0
    while [ "$index" -lt "${#packages[*]}" ];do
        printf "安装软件包\"${packages[$index]}\"....."
        if (yum install ${packages[$index]} -y &> /dev/null);then
           echo -e "\r\e[70G\e[32;1m[OK]\e[39;0m" 
        else
           echo -e "\r\e[70G\e[31;1m[ERROR]\e[39;0m" 
           exit 7
        fi
        let index+=1
    done
}

function init_system(){
    for i in "${service[@]}";do
        if (systemctl -q is-active $i);then
            systemctl disable --now $i
        fi
    done
    if [ "`sestatus | grep -wc enabled`" -ne 0 ];then
       sed -i '/SELINUX/ s:enforcing:disabled:g' $seconfig
    fi
}

function yum_repo_create(){
     local yum_work_dir='/etc/yum.repos.d'
     if [ ! -d "$yum_work_dir" ];then
        mkdir $yum_work_dir
     fi 
     touch $yum_work_dir/lan.repo
     if (grep -wq 'repo\.huaweicloud\.com' `ls $yum_work_dir/* | grep '/etc/\(.*\)' | grep -v ':' | xargs`);then
         sed -i '/^gpgcheck/ s:gpgcheck=1:gpgcheck=0:g'  /etc/yum.repos.d/*.repo
     else
         rm -rf $yum_work_dir
         if ! (tar -xf yum.tar.gz 2>/dev/null && mv yum.repos.d /etc -f);then
             echo '压缩包错误或者不存在' && exit 8
         else
             sed -i '/^gpgcheck/ s:gpgcheck=1:gpgcheck=0:g'  /etc/yum.repos.d/*.repo
         fi

     fi
}

load_kvm='
    complete='?'
    test "$complete" != '?' || \
   { modprobe kvm ;}    # 加载 kvm 模块
    if [ "$( lsmod | grep -c 'kvm' )" -ne 0 ];then
       {  complete="$(lsmod | grep -c 'kvm')" ;}
    else
       { complete='?' ;}
    fi
'

function main(){
   if ! (grep -q -e vmx -e svm /proc/cpuinfo);then
       echo -e '\e[31;1m请开启CPU虚拟化\e[39;0m'
       exit 7
   fi
   init_system
   update_interface
   yum_repo_create 
   install_kvm
   eval "$load_kvm"
   if [ "$complete" != '?' ];then
       systemctl start libvirtd 
       if (systemctl is-active --quiet libvirtd);then
           echo -e "\e[70G恭喜本机安装KVM服务成功" 
       else
           echo -e '\e[70GKVM服务失败!!!'
       fi
   fi
}
main
