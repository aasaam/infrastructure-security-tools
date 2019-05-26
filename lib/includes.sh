#!/bin/bash
export TZ=UTC

DARKGRAY='\033[1;30m'
RED='\033[0;31m'
LIGHTRED='\033[1;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
LIGHTPURPLE='\033[1;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
SET='\033[0m'

INFRASTRUCTURE_NS="aasaam"
INFRASTRUCTURE_TITLE="AASAAM"
INFRASTRUCTURE_NAME="Dadeh Pardazan Ati Prozheh ($INFRASTRUCTURE_TITLE)"
INFRASTRUCTURE_DOMAIN="aasaam.cloud"
INFRASTRUCTURE_EMAIL="postmaster@$INFRASTRUCTURE_DOMAIN"

DATE_YEAR=`date +"%Y"`
ROOT_YEARS="$(($DATE_YEAR + 8))"
INTERMEDIATE_YEARS="$(($DATE_YEAR + 4))"
SERVER_YEARS="$(($DATE_YEAR + 2))"
CLIENT_YEARS="$(($DATE_YEAR + 2))"

ROOT_DAYS=`python -c "from datetime import date; print (date($ROOT_YEARS,01,01)-date($DATE_YEAR,01,01)).days"`
INTERMEDIATE_DAYS=`python -c "from datetime import date; print (date($INTERMEDIATE_YEARS,01,01)-date($DATE_YEAR,01,01)).days"`
SERVER_DAYS=`python -c "from datetime import date; print (date($SERVER_YEARS,01,01)-date($DATE_YEAR,01,01)).days"`
CLIENT_DAYS=`python -c "from datetime import date; print (date($CLIENT_YEARS,01,01)-date($DATE_YEAR,01,01)).days"`

function render_template() {
  eval "echo \"$(cat $1)\""
}

DATA_DIR=$PROJECT_PATH/certs
OUTPUT_DIR=$PROJECT_PATH/output
PUBLIC_DIR=$OUTPUT_DIR/public
SERVER_OUT=$OUTPUT_DIR/servers
ROOT_DIR=$DATA_DIR/ca
INTERMEDIATE_DIR=$DATA_DIR/intermediate
SERVER_DIR=$DATA_DIR/servers
CLIENT_DIR=$DATA_DIR/clients

ROOT_EXTENSION=$ROOT_DIR/ca.conf
INTERMEDIATE_EXTENSION=$INTERMEDIATE_DIR/intermediate.conf
SERVER_EXTENSION=$SERVER_DIR/server.conf
SERVER_INTERNAL_EXTENSION=$SERVER_DIR/server_internal.conf
CLIENT_INTERNAL_EXTENSION=$SERVER_DIR/client_internal.conf
SERVER_LOCAL_EXTENSION=$SERVER_DIR/server_local.conf
CLIENT_EXTENSION=$CLIENT_DIR/client.conf

if [ -e "$PROJECT_PATH/config.sh" ]; then
  source $PROJECT_PATH/config.sh
fi
