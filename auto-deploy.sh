#!/usr/bin/env bash

#机器列表
HostList=`cat nodes.txt`
#端口号
Port=22

# 1.无交互生成密钥对
if [ ! -f ~/.ssh/id_rsa.pub ];then
    expect ssh-keygen.exp
fi

# 2.无交互分发公密钥
for v in ${HostList}
do
    expect send-sshkey.exp ~/.ssh/id_rsa.pub ${v}
    if [ $? -eq 0 ];then
        echo "公钥-发送成功：$v"
    else
        echo "公钥-发送失败：$v"
    fi
done

# 3.分发脚本文件(安装软件包)
for v in ${HostList}
do
    scp -P ${Port} -rp ~/env/scripts root@${v}:~
    if [ $? -eq 0 ];then
        echo "scripts-发送成功：$v"
    else
        echo "scripts-发送失败：$v"
    fi
done


# 4.使用脚本文件安装
for v in ${HostList}
do
    ssh -t -p ${Port} root@${v} /bin/bash ~/scripts/install.sh
done


