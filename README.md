# 服务器集群自动初始化脚本

之前介绍过ansible的使用，通过ssh授权批量控制服务器集群
但是生成密钥和分发公钥的时候都是需要确认密码的，这一步也是可以自动化的，利用ssh + expect + scp就可以实现，其实只用这几个命令结合也可以实现类似ansible的功能了
为了远程操作服务器进行环境初始化，总结我们都需要以下几步操作
1.ssh-keygen生成密钥对
2.将生成的公钥发送到node服务器
3.scp拷贝安装包到node服务器
4.ssh远程执行拷贝过去的安装包

下面进行集群环境初始化脚本的编写，通过ssh + expect + scp实现自动化集群环境搭建
## 第一步，服务器准备
这里使用docker模拟几台服务器，分别命名为node2,node3,node4（使用镜像chenqionghe/ubuntu，密码统一为88888888），生产环境为ip或host
```
docker run -d --name node2 -p 2223:22 chenqionghe/ubuntu
docker run -d --name node3 -p 2224:22 chenqionghe/ubuntu
docker run -d --name node4 -p 2225:22 chenqionghe/ubuntu
```
还得有一台主控制服务器node1，负责操作所有的服务器节点
```
docker run -d --name node1 -p 2222:22 \
--link node2:node2 \
--link node3:node3 \
--link node4:node4 \
chenqionghe/ubuntu
```
初始化完成后进入node1节点
```
ssh root@127.0.0.1 -p 2222
```
安装必须软件
```
apt-get install expect -y
```
创建存放脚本的目录～/env
```
mkdir -p ~/env && cd ~/env
```
这里先模拟一个简单的安装包scripts/install.sh，安装vim命令
```
mkdir scripts
cat > scripts/install.sh <<EOF
#!/bin/bash bash
apt-get install vim -y
EOF
```
创建机器列表配置文件，vim nodes.txt
```
node2
node3
node4
```

## 第二步 编写自动化脚本

1. 无交互ssh-keygen生成密钥对脚本，vim ssh-keygen.exp
```
#!/usr/bin/expect
#set enter "\n"
spawn ssh-keygen
expect {
        "*(/root/.ssh/id_rsa)" {send "\r";exp_continue}
        "*(empty for no passphrase)" {send "\r";exp_continue}
        "*again" {send "\r"}
}
expect eof
```
2.无交互分发公钥脚本，vim send-sshkey.exp
```
#!/usr/bin/expect
if { $argc != 2 } {
 send_user "usage: expect send-sshkey.exp file host\n"
 exit
}
#define var
set file [lindex $argv 0]
set host [lindex $argv 1]
set password "88888888"
spawn ssh-copy-id -i $file -p 22 root@$host
expect {
        "yes/no" {send "yes\r";exp_continue}
        "*password" {send "$password\r"}
}
expect eof
```
3.远程批量执行ssh脚本, vim mssh.sh
```
#!/bin/bash
Port=22
if [ $# -lt 1 ];then
    echo "Usage: `basename $0` command"
    exit
fi
echo $@
for v in `cat nodes.txt`
do
    ssh -t -p ${Port} root@${v} $@
    if [ $? -eq 0 ];then
        echo "执行成功：$v"
    else
        echo "执行失败：$v"
    fi
done
```
4.自动化部署脚本，vim auto-deploy.sh
```
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
```
# 第三步 执行脚本初始化查看效果
```
sh auto-deploy.sh
```
看到执行成功的结果
```
spawn ssh-keygen
...
公钥-发送成功：node2
...
公钥-发送成功：node3
...
公钥-发送成功：node4
install.sh 100% 40 41.4KB/s 00:00
scripts-发送成功：node2
install.sh 100% 40 45.0KB/s 00:00
scripts-发送成功：node3
install.sh 100% 40 39.9KB/s 00:00
scripts-发送成功：node4
...
Connection to node4 closed.
```

下面我们再来批量执行一下远程ssh命令脚本，批量查看系统类型
```
sh mssh.sh "cat /etc/os-release|head -n 1"
cat /etc/os-release|head -n 1
NAME="Ubuntu"
Connection to node2 closed.
执行成功：node2
NAME="Ubuntu"
Connection to node3 closed.
执行成功：node3
NAME="Ubuntu"
Connection to node4 closed.
执行成功：node4
```



















