#!/bin/bash

cd "${0%/*}"

SCRIPT_DIR=`pwd`
CONFIG_FILE="${SCRIPT_DIR}/conf/$1.cfg"
TARGET=$1

echo "=========== USING_CONFIG ======================"
echo ${CONFIG_FILE}
echo "==============================================="

log()  { echo "-----> $1" > /dev/stderr; }
warn() { echo "       $1" > /dev/stderr; }

docker_compose() {
  if [[ "${TARGET}" == "testing" ]]
  then
    cd ${SCRIPT_DIR}/../../
    mkdir -p log

    mkdir -p ${LOCAL_NGINX_FOLDER}
    sudo cp ${SCRIPT_DIR}/nginx/local.nginx.conf ${LOCAL_NGINX_FOLDER}/vhost.d/${VIRTUAL_HOST}
    cp ./scripts/deploy/docker-compose/docker-compose-testing.yml docker-compose.yml

    docker-compose build
    docker-compose up -d
  elif [[ "${TARGET}" == "local" ]]
  then
    cd ${SCRIPT_DIR}/../../
    mkdir -p log

    mkdir -p ${LOCAL_NGINX_FOLDER}
    sudo cp ${SCRIPT_DIR}/nginx/local.nginx.conf ${LOCAL_NGINX_FOLDER}/vhost.d/${VIRTUAL_HOST}
    cp ./scripts/deploy/docker-compose/docker-compose-local.yml docker-compose.yml

    docker-compose stop
    docker-compose rm -f

    docker-compose build
    docker-compose up -d
  fi
}

parse_env() {
  if [[ ! -f ${CONFIG_FILE} ]]; then
    warn "File ${CONFIG_FILE} not found!"
    exit 1
  fi

  cp ${CONFIG_FILE} ${SCRIPT_DIR}/../../.env

  export $(grep "^[^#]*=.*" ${CONFIG_FILE} | xargs -d"\t")
}

main() {

  parse_env
  docker_compose

}

main $@
