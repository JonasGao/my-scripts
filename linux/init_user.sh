#!/bin/bash
[ -z "$1" ] && echo "Please provide a password" && exit 1
[ "${#1}" -lt 8 ] && echo "Password length must greater then 8" && exit 2
ADD_USER="<Please replace here>"
echo "Adding user $ADD_USER"
useradd $ADD_USER
echo "Succeed add user $ADD_USER"
echo -e "$1\n$1\n" | passwd --stdin $ADD_USER
echo "Changed $ADD_USER password"