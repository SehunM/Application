#! /usr/bin/env bash

set -o errexit 
set -o pipefail
set -o nounset 

service='nginx.service'
work_dir='/var/www/html'
tar_packages="nginx-conf.tar.gz nginx-private-CA.tar.gz nginx-share.tar.gz shell-scripts.tar.gz yum-repos.tar.gz"

function file_move(){
    #conf-backend
    tar -xf nginx-conf.tar.gz 2>/dev/null
    rm -rf /etc/nginx
    mv nginx /etc/nginx
    
    #CA-http-->https
    tar -xf nginx-private-CA.tar.gz 2>/dev/null
    if [ -d '/etc/pki/nginx/' ];then
        rm -rf /etc/pki/nginx/
    fi
    mv  nginx  /etc/pki/nginx/ -f
    
    #web-frontend
    tar -xf nginx-share.tar.gz 2>/dev/null
    rm -rf /usr/share/nginx/
    rm -rf /usr/share/doc/HTML/
    \cp -arf share/doc/HTML/ /usr/share/doc/HTML -f
    \cp -arf share/nginx/ /usr/share/ -f
    rm -rf share/
    
    #scripts
    tar -xf shell-scripts.tar.gz 2>/dev/null
    \cp -af ./scripts/{install_openssl.sh,install_git_2.45.sh,install_mongodb_7.0.sh}  $work_dir
    \cp -af lan.repo $work_dir
}

for gz in  $tar_packages;do
   if [ -s "$gz" ];then
      continue
   else
      echo "\"$gz\"不存在或文件错误,退出脚本"
      exit 7
   fi
done
file_move
systemctl enable --now $service
