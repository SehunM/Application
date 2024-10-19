#! /usr/bin/env bash

set -o errexit

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

funnction file_move(){
    local work_dir="$PWD"
    \cp -af ./{named.localhost,named.loopback}  /var/named/ && \
    \cp -af ./{named.conf,named.rfc1912.zones} /etc
    \cp -af ./ifcfig-eth0   /etc/sysconfig/network-scripts
}


if -z "$(rpm -qa bind)";then
     yum -y install bind
fi
file_move
systemctl enable --now named.service
systemctl restart network
