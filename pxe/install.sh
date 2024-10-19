#! /usr/bin/env bash

set -o errexit
set -o pipefail

packages='tftp-server dhcp syslinux vsftpd'
function yum_repo_create(){
    rm -rf /var/cache/yum
    printf "yum仓库创建中...." 
    local yum_work_dir='/etc/yum.repos.d'
    if (grep -wq 'repo\.huaweicloud\.com' `ls $yum_work_dir/* | grep '/etc/\(.*\)' | grep -v ':' | xargs`);then
        sed -i '/^gpgcheck/ s:gpgcheck=1:gpgcheck=0:g'  /etc/yum.repos.d/*.repo
        echo -e "\r\e[70G\e[32;1m[OK]\e[39;0m"
    else
        rm -rf /etc/yum.repos.d
        if ! (tar -xf yum.tar.gz 2>/dev/null && mv yum.repos.d /etc -f);then
             echo -e "\r\e[70G\e[32;1m[ERROR]\e[39;0m"
             exit 8
        else
            sed -i '/^gpgcheck/ s:gpgcheck=1:gpgcheck=0:g'  /etc/yum.repos.d/*.repo
            echo -e "\r\e[70G\e[32;1m[OK]\e[39;0m"
        fi
    fi
}

function install_packages(){
    for i in $packages;do
        printf "软件包\"$i\"安装中...." 
        if (yum -y install $i >& /dev/null);then
            echo -e "\r\e[70G\e[32;1m[OK]\e[39;0m"
        else
            echo -e "\r\e[70G\e[31;1m[ERROR]\e[39;0m"
        fi
    done
}

function copy_file(){
  local boot_copy='\cp -rf ./tftpboot  /var/lib/'
  printf "配置文件拷贝中...." 

  # system install order
  if [ -d '/var/ftp/ks_config' ];then
     \cp -rf ./ks_config /var/ftp
  else
     rm -rf /var/ftp/ks_config
     \cp -rf ./ks_config /var/ftp
  fi

  # tftp-server config set
  if [ -e /etc/xinetd.d/tftp ];then
     sed -i '/disable/ s:yes:no:g' /etc/xinetd.d/tftp
  else
     mkdir -p /etc/xinetd.d && \
     \cp -af ./tftp /etc/xinetd.d/tftp
  fi

  # dhcp set
  if [ -e '/etc/dhcp/dhcpd.conf' ];then
      rm -f /etc/dhcp/dhcpd.conf
      \cp -f ./dhcpd.conf /etc/dhcp/dhcpd.conf
  else
      \cp -f ./dhcpd.conf /etc/dhcp/dhcpd.conf
  fi

  # boot files
  if [ -n "`mount | grep 'sr0'`" ];then
    \cp -af /usr/share/syslinux/pxelinux.0  /var/lib/tftpboot/ && \
    \cp -af /var/ftp/pub/isolinux/{vesamenu.c32,boot.msg,splash.png}   /var/lib/tftpboot/ && \
    \cp -af /var/ftp/pub/images/pxeboot/{vmlinuz,initrd.img}   /var/lib/tftpboot/
     mkdir -p /var/lib/tftpboot/pxelinux.cfg
    \cp -af ./tftpboot/pxelinux.cfg/default /var/lib/tftpboot/pxelinux.cfg/default
     echo -e "\r\e[70G\e[32;1m[OK]\e[39;0m"
  else
      if [ -z "$(ls /var/lib/tftpboot)" ];then
         eval "$boot_copy"
      else
         rm -rf  /var/lib/tftpboot
         eval "$boot_copy"
      fi
      echo -en "\r\e[70G\e[31;1m[WORNING]\e[39;0m"
      echo -e "\r\e[81G\e[31;1mDVD文件并未挂载,请挂载DVD文件,否则PXE服务将不可用\e[39;0m"
  fi

}

function service_start(){
    local service=(tftp.socket dhcpd vsftpd)
    for i in "${service[@]}";do
        printf "\"$i\"服务启动中...." 
        if systemctl enable --now $i &>/dev/null;then
            echo -e "\r\e[70G\e[32;1m[OK]\e[39;0m"
        else
            echo -e "\r\e[70G\e[31;1m[ERROR]\e[39;0m"
            echo -e "\r\e[81G\e[31;1m请运行\"journalctl -exu $i\"查看\e[39;0m"
        fi   
    done
}

function main(){
    yum_repo_create
    install_packages
    copy_file
    service_start
}
main
