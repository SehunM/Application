#! /usr/bin/env bash

set -o errexit

seconfig='/etc/selinux/config'
service='(NetworkManager postfix firewalld)'

function install_kvm(){
    yum upgrade
    packages=(kvm virt-manager libvirt libvirt-python python-virtinst libvirt-client qemu-kvm qemu-img)
    index=0
    until [ "$index" -gt "${#packages[*]}" ];do
        yum install ${packages[$index]} -y
        let index+=1
    done
    if (grep -q -e vmx -e nx -e svm /proc/cpuinfo);then
        return 0
    else
        echo -e '\e[31;1m请开启CPU虚拟化\e[39;0m'
        exit 7
    fi
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
     if (grep -wq 'repo\.huaweicloud\.com' `ls $yum_work_dir/* | grep '/etc/\(.*\)' | grep -v ':' | xargs`);then
         sed -i '/^gpgcheck/ s:gpgcheck=1:gpgcheck=0:g'  /etc/yum.repos.d/*.repo
     else
         rm -rf /etc/yum.repos.d
         if ! (tar -xf yum-repos.tar.gz 2>/dev/null && mv yum.repos.d /etc -f);then
             echo '压缩包错误或者不存在' && exit 8
         else
             sed -i '/^gpgcheck/ s:gpgcheck=1:gpgcheck=0:g'  /etc/yum.repos.d/*.repo
         fi

     fi
}

function start_kvm(){
    modprobe kvm    # 加载 kvm 模块
    if lsmod | grep -q 'kvm';then
       systemctl start libvirtd && systemctl status libvirtd
    fi
    # kvm bridge interface 
    tar -xf interfaces.tar.gz && mv interfaces/* /etc/sysconfig/network-scripts/ -f
    read -p '请输入主机地址:' -e IP
    if [ -n "$IP" ];then
        if [[ "$IP" =~ ^(2[0-5][0-5]|[1][0-9][0-9]|[0-9][0-9]?)(\.(2[0-5][0-5]|[1][0-9][0-9]|[0-9][0-9]?)){3}$ ]];then
            sed -i '/IPADDR/d' /etc/sysconfig/network-scripts/ifcfg-br0 && \
            sed -i "/PREFIX/i IPADDR=$IP" /etc/sysconfig/network-scripts/ifcfg-br0 && \
        else
            printf "\e[31;3;1m%s %s\e[39;0m\n" "$IP 不合法" '!!'
            exit 2
        fi
    else
       echo "网卡保存默认设置"
    fi
    systemctl restart network
}

function main(){
   init_system && \
   yum_repo_create && \
   install_kvm && \ 
   start_kvm 
}

main
