#! /usr/bin/env bash

set -e
set -o pipefail

function variable(){
    if [ -n "$(ls /usr/local/openssl/bin)" ];then
        if [ "$(grep -c 'OPENSSL_CUSTOME' /etc/bashrc)" -ne 2 ];then
           echo -e 'export OPENSSL_CUSTOME="/usr/local/openssl/bin"\nPATH="$OPENSSL_CUSTOME:$PATH"' >> /etc/bashrc 
        fi
    fi
}

yum install perl-IPC-Cmd  perl perl-devel gcc -y
if [  ! -e 'openssl-3.2.3.tar.gz' ];then
    wget https://github.com/openssl/openssl/releases/download/openssl-3.2.3/openssl-3.2.3.tar.gz
fi
tar -xvf openssl-3.2.3.tar.gz && cd openssl-3.2.3 && ./Configure --prefix=/usr/local/openssl && make && make install

if ! (/usr/local/openssl/bin/openssl version >& /dev/null);then
    [ -s "/etc/ld.so.conf.d/openssl-3.2.3.conf" ] || touch /etc/ld.so.conf.d/openssl-3.2.3.conf && \
    echo '/usr/local/openssl/lib64' > /etc/ld.so.conf.d/openssl-3.2.3.conf && \
    ldconfig && /usr/local/openssl/bin/openssl version >& /dev/null && variable
fi
echo -en "\e[35;1m老版本\e[20G:\e[39;0m" && openssl version
set +e
{ source /etc/bashrc ;}
echo -en "\e[32;1m新版本\e[20G:\e[39;0m" && openssl version
echo -e "\e[35;4;1m由于稳定性需要退出终端,请再次登录即可正常使用,logout.....\e[39;0m"
kill -9 $PPID
