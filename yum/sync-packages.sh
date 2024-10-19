#! /usr/bin/env bash

set -o errexit 
set -o pipefail
set -o nounset 

server_package='nginx'
yum_tool='yum-utils'
matedata_create_tool='createrepo'
system_pass=false
work_dir='/var/www/html'
desk_size="`tr -d 'G'<<<$(awk '{print $2}'< <(df -h | grep '\/var\/www\/html'))`"

function check(){
    if [ ! -d "$work_dir" ];then
       mkdir -p $work_dir
    fi
    if [[ -n "$desk_size"  && "$desk_size" -ge 80 ]];then
       { system_pass=true ;}
    else
       echo "系统资源不足,请添加新硬盘挂载到\"$work_dir\"下"
       exit 7
    fi
}

check
if [ "$system_pass" == "true" ];then
    if (grep -wq 'repo\.huaweicloud\.com' `ls /etc/yum.repos.d/* | grep '/etc/\(.*\)' | grep -v ':' | xargs`);then
        sed -i '/^gpgcheck/ s:gpgcheck=1:gpgcheck=0:g'  /etc/yum.repos.d/*.repo
        yum install $server_package $matedata_create_tool $yum_tool -y 
    else
        rm -rf /etc/yum.repos.d
        if ! (tar -xf yum-repos.tar.gz 2>/dev/null && mv yum.repos.d /etc -f);then
             echo '压缩包错误或者不存在' && exit 8
        else
             yum install $server_package $matedata_create_tool $yum_tool -y 
             sed -i '/^gpgcheck/ s:gpgcheck=1:gpgcheck=0:g'  /etc/yum.repos.d/*.repo
        fi
    fi
    reposync -r base -r updates  -r extras -p $work_dir/centos/7/os/x86_64 && \
    reposync -r k8s-v1.29 -r k8s-v1.30 -r k8s-v1.31 -p $work_dir/kubernetes && \
    reposync -r epel -p $work_dir && \
    reposync -r mongodb-org-7.0 -p $work_dir && \
    reposync -r docker-ce-stable -p $work_dir && \
    if [[ $? -eq 0 ]];then
       createrepo -pv --update $work_dir/centos/7/os/x86_64/base/ && createrepo -pv --update  $work_dir/centos/7/os/x86_64/updates/ && \
       createrepo -pv --update $work_dir/centos/7/os/x86_64/extras  && createrepo -pv --update $work_dir/docker-ce-stable/ && \
       createrepo -pv --update  $work_dir/kubernetes/k8s-v1.29/x86_64 && createrepo  -pv --update $work_dir/kubernetes/k8s-v1.30/x86_64  && \
       createrepo -pv --update $work_dir/kubernetes/k8s-v1.31/x86_64 && createrepo  -pv --update $work_dir/epel/ && \
       createrepo -pv --update $work_dir/mongodb-org-7.0/
    fi
else
    echo '同步失败，无法创建matedata!!'
fi

