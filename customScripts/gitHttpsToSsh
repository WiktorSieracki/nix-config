#!/bin/bash

remote=$(git remote -v)
remote_list=($remote)

for ((i=0; i<${#remote_list[@]}; i+=3)); do
  name=${remote_list[i]}
  url=${remote_list[i+1]}

  if [[ $url == https://* ]]; then
    ssh_url=$(echo $url | sed -e 's/^https:\/\/\(.*\)\/\(.*\)$/git@\1:\2/')
    ssh_url=$(echo $ssh_url | sed -e 's/\(.*\)\/\(.*\):\(.*\)$/\1:\2\/\3/')
    git remote set-url $name $ssh_url
    echo "Updated $name from $url to $ssh_url"
  fi
done
