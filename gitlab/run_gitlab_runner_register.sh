#!/bin/bash

sudo docker run --rm -t -i -v /srv/gitlab-runner/config:/etc/gitlab-runner gitlab/gitlab-runner register

#sudo vim /srv/gitlab-runner/config/config.toml
