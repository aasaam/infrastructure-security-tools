#!/bin/bash

# init
SCRIPT="$(readlink --canonicalize-existing "$0")"
PROJECT_PATH=`dirname $SCRIPT`
PCWD=`pwd`

# includes
source $PROJECT_PATH/lib/includes.sh

if [ "$PROJECT_PATH" != "$PCWD" ]; then
  echo -e "${RED}Go to ${YELLOW}$PROJECT_PATH${RED} and then try again.${SET}"
  exit
fi

CLIENTS_DIR=$DATA_DIR/clients

rm -rf output certs
tar -xf ca.tgz

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
  echo "You must enter name, username and email. $SCRIPT 'Maryam Haghgou' 'mary' 'mary@mary.tld'"
  exit 1
fi

if [ "$CA_DEV" == "1" ] && [[ -v CA_DEV_PASS ]]; then
  ROOT_PASSWORD=$CA_DEV_PASS
  CERT_PASSWORD=$CA_DEV_PASS
  CERT_P12_PASSWORD=$CA_DEV_PASS
  SSH_PASSWORD=$CA_DEV_PASS
  SSH_PASSWORD2=$CA_DEV_PASS
  PGP_PASSWORD=$CA_DEV_PASS
  PGP_PASSWORD2=$CA_DEV_PASS
else
  echo -e "${BLUE}CA HOLDER: Enter root ca password:${SET}"
  read -s ROOT_PASSWORD

  echo -e "${CYAN}Client: Enter certificate private key password (Once per user):${SET}"
  read -s CERT_PASSWORD

  echo -e "${CYAN}Client: Enter client certificate password (Every time want to use client auth):${SET}"
  read -s CERT_P12_PASSWORD

  echo -e "${YELLOW}Enter SSH passphrase:${SET}"
  read -s SSH_PASSWORD

  echo -e "${YELLOW}Enter SSH passphrase again:${SET}"
  read -s SSH_PASSWORD2

  echo -e "${YELLOW}Enter GPG passphrase:${SET}"
  read -s PGP_PASSWORD

  echo -e "${YELLOW}Enter GPG passphrase again:${SET}"
  read -s PGP_PASSWORD2
fi

if [ "$SSH_PASSWORD" != "$SSH_PASSWORD2" ]; then
  echo "Passphrase did not matched."
  exit
fi

if [ "$PGP_PASSWORD" != "$PGP_PASSWORD2" ]; then
  echo "Passphrase did not matched."
  exit
fi

CLIENT_NAME=$1
CLIENT_USER=$2
CLIENT_EMAIL=$3
FILENAME=$(echo $CLIENT_USER | sed -e 's/[^A-Za-z0-9._-]/_/g' | tr '[:upper:]' '[:lower:]')
CL_DIR=$CLIENTS_DIR/$FILENAME

if [ -d "$CL_DIR" ]; then
  echo "Client exist. skipped."
  exit
fi

CLIENT_NS_PATH=$CL_DIR/.$INFRASTRUCTURE_NS
CLIENT_EXTENSION_FILENAME="$CLIENT_NS_PATH/openssl.conf"

mkdir -p $CLIENT_NS_PATH
mkdir -p $CLIENT_NS_PATH/private
mkdir -p $CLIENT_NS_PATH/csr
mkdir -p $CLIENT_NS_PATH/certs
mkdir -p $CL_DIR/.ssh
mkdir -p $CL_DIR/.gnupg
chmod 700 $CL_DIR/.gnupg

cd $DATA_DIR

echo -e "${RED}Client certificate: ${SET}"

render_template $PROJECT_PATH/templates/openssl.client.conf.ini > $CLIENT_EXTENSION_FILENAME

KEYSIZE=2048

openssl genrsa -aes256 -passout pass:"$CERT_PASSWORD" \
  -out $CLIENT_NS_PATH/private/client.key.pem $KEYSIZE
chmod 400 $CLIENT_NS_PATH/private/client.key.pem

openssl req -batch -passin pass:"$CERT_PASSWORD" -config $CLIENT_EXTENSION_FILENAME \
  -key $CLIENT_NS_PATH/private/client.key.pem \
  -new -sha256 -out $CLIENT_NS_PATH/csr/client.csr.pem

faketime -f "$DATE_YEAR-01-01 00:00:00" openssl ca -batch -passin pass:"$ROOT_PASSWORD" -config $CLIENT_EXTENSION_FILENAME \
  -extensions usr_cert -days $CLIENT_DAYS -notext -md sha256 \
  -in $CLIENT_NS_PATH/csr/client.csr.pem \
  -out $CLIENT_NS_PATH/certs/client.cert.pem
chmod 444 $CLIENT_NS_PATH/certs/client.cert.pem

openssl pkcs12 -export -passin pass:"$CERT_PASSWORD" -passout pass:"$CERT_P12_PASSWORD" -out $CL_DIR/$INFRASTRUCTURE_NS.p12 \
  -in $CLIENT_NS_PATH/certs/client.cert.pem \
  -inkey $CLIENT_NS_PATH/private/client.key.pem

rm $CLIENT_EXTENSION_FILENAME
echo -e "${GREEN}Done.${SET}"

echo -e "${RED}SSH: ${SET}"
echo -e "${CYAN}Generating...${SET}"
ssh-keygen -t rsa -b 4096 -C "$CLIENT_EMAIL" -q -N "$SSH_PASSWORD" -f $CL_DIR/.ssh/id_rsa
ssh-keygen -t ed25519 -a 100 -C "$CLIENT_EMAIL" -q -N "$SSH_PASSWORD" -f $CL_DIR/.ssh/id_ed25519
SSH_RSA_PUB=`cat $CL_DIR/.ssh/id_rsa.pub`
SSH_ED25519_PUB=`cat $CL_DIR/.ssh/id_ed25519.pub`
echo -e "${GREEN}Done.${SET}"

echo -e "${RED}GPG: ${SET}"
echo -e "${CYAN}Generating...${SET}"
render_template $PROJECT_PATH/templates/gpg > $CLIENT_NS_PATH/gnupg.conf
gpg2 --homedir $CL_DIR/.gnupg/ --batch --gen-key $CLIENT_NS_PATH/gnupg.conf
rm $CLIENT_NS_PATH/gnupg.conf
PGP_KEY_ID=`gpg2 --homedir $CL_DIR/.gnupg/ --list-keys | egrep -o '[A-Z0-9]{40}'`
PGP_PUBLIC_KEY=`gpg2 --homedir $CL_DIR/.gnupg/ --armor --export`
echo -e "${GREEN}Done.${SET}"

render_template $PROJECT_PATH/templates/gitconfig > $CL_DIR/.gitconfig
render_template $PROJECT_PATH/templates/README.md > $CL_DIR/README.md

cd $CLIENTS_DIR
if [ -f "$ROOT_DIR/certs/ca.cert.pem" ]; then
  cp $ROOT_DIR/certs/ca.cert.crt $CLIENT_NS_PATH/$INFRASTRUCTURE_NS-certificate.crt
  cp $ROOT_DIR/certs/ca.cert.pem $CLIENT_NS_PATH/$INFRASTRUCTURE_NS-certificate.pem
fi

tar -czf $FILENAME.tgz $FILENAME
mkdir -p $OUTPUT_DIR
mv $FILENAME.tgz $OUTPUT_DIR/$FILENAME.tgz
