#! /usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

declare -a files
files=
host_IP="$(hostname -I|awk 'NR==1'|tr -d '[:space:]')"
interface_name="$(tr -d '[:space:]'<<<$(ip a | grep -B2 $host_IP | grep '^[[:digit:]]' | cut -d ':' -f2))"
CIDR="$(ip a | grep $host_IP | awk '{print $2}' | cut -d '/' -f2)"
files_char="`find ./ -name "*" -type f -exec egrep '(2[0-5][0-5]|[1][0-9][0-9]|[0-9][0-9]?)(\.(2[0-5][0-5]|[1][0-9][0-9]|[0-9][0-9]?)){3}' -l {} \;| xargs -n1 | grep -v '\.sh$' | grep -v '\.swp$'`"
if [ ! -s "./source_file_list.txt" ];then  #不存在或且大小为0
   echo "$files_char" > source_file_list.txt
   echo "初始文件列表保存在文件\"source_file_list.txt\"中"
fi
for file in $files_char;do
    files=(${files[*]} $file)
done

function update_file(){
     \cp -rf ./ks_config/* /var/ftp/ks_config
     \cp -f ./dhcpd.conf /etc/dhcp/dhcpd.conf
     \cp -af ./tftpboot/pxelinux.cfg/default /var/lib/tftpboot/pxelinux.cfg/default
     systemctl restart dhcpd
}

function static(){
    local interface="/etc/sysconfig/network-scripts/ifcfg-${interface_name}"
    if [ "`grep -c 'static' $interface`" -ne 1 ];then
        echo -e "IPADDR=$host_IP\nPREFIX=$CIDR\nGATEWAY=172.17.0.100" >> $interface
    fi
    sed -i '/BOOTPROTO/ s$dhcp$static$g' $interface
    systemctl restart network
}

function default(){
     if [ "$(echo ${files[*]} | xargs -n1 | grep '\.bak' -c)" -lt 1 ];then
         for x in "${files[@]}";do
             if (grep -q '172\.17\.0\.250' "$x");then 
                 sed -i "/172\.17\.0\.250/ s:172.17.0.250:$host_IP:g" -i.bak $x 
                 if [ "$?" -eq 0 ];then
                     echo -n "设置本机网卡IP\"$host_IP\","
                     echo "本机网卡名\"$interface_name\"作为pxe服务的接口,备份源文件路径\"$x.bak\""
                     update_file
                 fi
                 continue
             fi
         done
     else
         echo '请勿重复执行????!!!'
     fi
}

function custom(){
    for i in ${files[*]};do 
       if ! [[ $i =~ \.bak$ ]];then
           while read -p "\"$i\"是否修改?(Y/N): " -n1 cmd;do
               if [[ x"$cmd" == x"Y" || x"$cmd" == x"y" || x"$cmd" == x"N"|| x"$cmd" == x"n" ]];then 
                  case $cmd in
                      Y|y) while true; echo && read -p "(查看/修改)?(C/E): " -n1 cmd1;do 
                              case $cmd1 in
                                 c|C)echo && cat $i;;
                                 E|e)vi $i;;
                                 *)echo && echo -e "\e[60G\e[33m退出\"$i\"\e[39;0m"&& break;;
                              esac
                           done
                      ;;
                      N|n) echo -e '\e[60G\e[33m[SKIP]\e[39;0m' && break
                      ;;
                  esac
               else
                  echo -e '\e[60G\e[31m[ERROR]\e[39;0m' 
                  break
               fi
           done
       else  
           continue
       fi
    done
}

function main(){
   default
   read -p "自定义配置文件?(Y/N): " -n1 cmd
   if [[ x"$cmd" == x"Y" || x"$cmd" == x"y" ]];then
       echo
       custom
       update_file
   else
       echo 
       exit 0
   fi
   static
}
main

