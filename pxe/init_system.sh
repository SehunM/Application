#! /usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

seconfig='/etc/selinux/config'
service='(NetworkManager postfix firewalld)'
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

function dvd_mount(){
   if [ -e '/dev/sr0' ];then
       if ! (mount | grep -q '\bsr0\b');then
           mount -t iso9660 /dev/sr0 /var/ftp/pub
       fi
       if [ "$(grep -c 'sr0' /etc/fstab)" -ne 1 ];then
            echo -e "/dev/sr0\t\t\t\t /var/ftp/pub\t\t  iso9660 defaults\t  0 0" >> /etc/fstab
            init 6
       fi
   else
       echo "请连接上DVD再执行一遍$0"
   fi
}

function main(){
  init_system
  dvd_mount
  hostnamectl set-hostname _pxe_server
}
main
