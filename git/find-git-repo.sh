#!/bin/bash

find ${1} -type d -maxdepth ${2} | while read line; do
  git_dir="${line}/.git"
  if [[ -d ${git_dir} ]]; then
    echo $line
  fi
done
