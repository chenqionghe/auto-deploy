#!/bin/bash
Port=22
if [ $# -lt 2 ];then
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
