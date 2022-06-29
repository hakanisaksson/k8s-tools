#!/bin/bash
#
# Detect all namespaced k8s objects and dump them
#
savedir=`kubectl config current-context`
mkdir -p $savedir

objs=$(kubectl api-resources --no-headers --namespaced=true | grep -vE 'bindings|localsubjectaccessreviews' |awk '{printf $1","}' | sed 's#,$##')

cmd="./dump_all -o ${objs} -s ${savedir}/"
echo $cmd
$cmd

