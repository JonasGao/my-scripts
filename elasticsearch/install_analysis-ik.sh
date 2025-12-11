#!/bin/bash
VERSION="7.17.7"
URL="https://github.com/medcl/elasticsearch-analysis-ik/releases/download/v${VERSION}/elasticsearch-analysis-ik-${VERSION}.zip"
echo "Install $URL"
docker compose exec elasticsearch elasticsearch-plugin install "$URL"