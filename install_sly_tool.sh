#!/bin/bash

function check_docker_status
{
   ###检查docker 是否运行   ###
   `systemctl status docker >/dev/null 2>&1`
   echo "$?"
}

function install_docker_offline
{
  mkdir -p /opt/kube/bin /TRS/APP /etc/docker
  systemctl stop firewalld
  yum remove -y firewalld python-firewall firewalld-filesystem
  tar -xvzf package/docker-19.03.8.tgz  -C package/
  /usr/bin/cp package/docker/* /opt/kube/bin/
  chmod 755 /opt/kube/bin/*
  ln -s /opt/kube/bin/docker /usr/bin/docker

  iptables -P INPUT ACCEPT && iptables -F && iptables -X  && iptables -F -t nat && iptables -X -t nat  && iptables -F -t raw && iptables -X -t raw  && iptables -F -t mangle && iptables -X -t mangle

  cat package/daemon.json >/etc/docker/daemon.json
  cat package/docker.service >/etc/systemd/system/docker.service
  /usr/sbin/setenforce 0
  systemctl daemon-reload && systemctl restart docker && systemctl enable docker

  is_docker_running='false'
  for (( i=0;i<10;i++ ))
  do
     `systemctl status docker >/dev/null 2>&1`
     ret_code=$?

     if [[ "${ret_code}" == "0" ]]
     then
         is_docker_running='true'
         break
     fi

     echo "Docker is not running,retrying again......"
     sleep 2
  done

  if [[ "${is_docker_running}" == "false" ]]
  then
     echo "无法启动docker,程序退出"
     exit 1
  fi

}




ret_code=$(check_docker_status)

if [[ "${ret_code}" != "0" ]]
then
   #install_docker_offline
   echo '未检测到Docker, 程序退出'
   exit 1
fi

docker_exec=$(which docker || echo "/opt/kube/bin/docker")

echo "导入 石榴云 安装工具 镜像"
${docker_exec} load -i image/install_sly_image.tar.gz

if [ ! -d 'install_sly' ]
then
  echo '解压install_sly.tar.gz'
  tar -xvzf install_sly.tar.gz
else
  echo "检测到install_sly 目录，跳过解压.."
fi

echo "启动ansible 容器"
/usr/sbin/setenforce 0

mkdir kubeconfig

${docker_exec} run -it -d  -e LC_ALL='en_US.UTF-8'  -v `pwd`/install_sly:/home/install_sly -v `pwd`/kubeconfig:/root/.kube  --name install_sly  install_sly:latest  bash
