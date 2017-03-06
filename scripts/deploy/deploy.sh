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
    docker-compose -f ./scripts/deploy/docker-compose/docker-compose-testing.yml build
    docker-compose -f ./scripts/deploy/docker-compose/docker-compose-testing.yml up -d
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
