#!/bin/bash

r() {
  sudo docker run --rm -v /srv/gitlab-runner/config:/etc/gitlab-runner gitlab/gitlab-runner register \
    --non-interactive \
    --executor "docker" \
    --docker-image maven:3 \
    --url "$GITLAB_URL" \
    --registration-token "${1}" \
    --description "${2}-runner" \
    --run-untagged="true" \
    --locked="false" \
    --access-level="not_protected"
}

r $TOKEN $NAME
