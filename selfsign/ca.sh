#!/bin/bash

set -e

CA_C="CN"
CA_CN="XxShanghai"
CA_KEY="ca.key"
CA_DATE="3650"
CA_CERT="ca.pem"
SSL_SIZE="2048"

openssl genrsa -out ${CA_KEY} ${SSL_SIZE}
openssl req -x509 -sha256 -new -nodes -key ${CA_KEY} -days ${CA_DATE} -out ${CA_CERT} -subj "/C=${CA_C}/CN=${CA_CN}"
