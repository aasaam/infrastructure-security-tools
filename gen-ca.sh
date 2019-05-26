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

if [ "$CA_DEV" == "1" ]; then
  rm -rf output certs *.tgz
fi

if [ -d "$ROOT_DIR" ]; then
  echo "CA directory exist. skipped."
  exit
fi

if [ "$CA_DEV" == "1" ] && [[ -v CA_DEV_PASS ]]; then
  ROOT_PASSWORD=$CA_DEV_PASS
  ROOT_PASSWORD2=$CA_DEV_PASS
  ROOT_PASSWORD3=$CA_DEV_PASS
  INT_PASSWORD=$CA_DEV_PASS
  INT_PASSWORD2=$CA_DEV_PASS
else
  echo -e "${RED}Enter root ca password:${SET}"
  read -s ROOT_PASSWORD

  echo -e "${RED}Enter root ca password again:${SET}"
  read -s ROOT_PASSWORD2

  echo -e "${RED}Enter root ca password once again:${SET}"
  read -s ROOT_PASSWORD3

  echo -e "${RED}Enter intermediate password:${SET}"
  read -s INT_PASSWORD

  echo -e "${RED}Enter intermediate password again:${SET}"
  read -s INT_PASSWORD2
fi

if [ "$ROOT_PASSWORD" != "$ROOT_PASSWORD2" ] || [ "$ROOT_PASSWORD" != "$ROOT_PASSWORD3" ]; then
  echo "Password did not matched."
  exit
fi

if [ "$INT_PASSWORD" != "$INT_PASSWORD2" ]; then
  echo "Password did not matched."
  exit
fi

mkdir -p $ROOT_DIR
mkdir -p $INTERMEDIATE_DIR
mkdir -p $PUBLIC_DIR

cd $DATA_DIR
mkdir $ROOT_DIR/certs $ROOT_DIR/crl $ROOT_DIR/newcerts $ROOT_DIR/private
chmod 700 $ROOT_DIR/private
touch $ROOT_DIR/index.txt
touch $ROOT_DIR/index.txt.attr
echo 1000 > $ROOT_DIR/serial
openssl genrsa -aes256 -passout pass:"$ROOT_PASSWORD" -out $ROOT_DIR/private/ca.key.pem 4096

render_template $PROJECT_PATH/templates/openssl.ca.conf.ini > $ROOT_EXTENSION
faketime -f "$DATE_YEAR-01-01 00:00:00" openssl req -batch -passin pass:"$ROOT_PASSWORD" -config $ROOT_EXTENSION \
  -key $ROOT_DIR/private/ca.key.pem \
  -new -x509 -days $ROOT_DAYS -sha256 -extensions v3_ca \
  -out $ROOT_DIR/certs/ca.cert.pem

chmod 444 $ROOT_DIR/certs/ca.cert.pem

echo -e "${RED}Root CA verify: ${SET}"
openssl x509 -noout -text -in $ROOT_DIR/certs/ca.cert.pem

mkdir $INTERMEDIATE_DIR/certs $INTERMEDIATE_DIR/crl $INTERMEDIATE_DIR/csr $INTERMEDIATE_DIR/newcerts $INTERMEDIATE_DIR/private
chmod 700 $INTERMEDIATE_DIR/private
touch $INTERMEDIATE_DIR/index.txt
echo 1000 > $INTERMEDIATE_DIR/serial
echo 1000 > $INTERMEDIATE_DIR/crlnumber
openssl genrsa -aes256  -passout pass:"$INT_PASSWORD" -out $INTERMEDIATE_DIR/private/intermediate.key.pem 4096
chmod 400 $INTERMEDIATE_DIR/private/intermediate.key.pem

render_template $PROJECT_PATH/templates/openssl.intermediate.conf.ini > $INTERMEDIATE_EXTENSION

openssl req -batch -passin pass:"$INT_PASSWORD" -config $INTERMEDIATE_EXTENSION -new -sha256 \
  -key $INTERMEDIATE_DIR/private/intermediate.key.pem \
  -out $INTERMEDIATE_DIR/csr/intermediate.csr.pem

faketime -f "$DATE_YEAR-01-01 00:00:00" openssl ca -batch -passin pass:"$ROOT_PASSWORD" -config $ROOT_EXTENSION -extensions v3_intermediate_ca \
  -days $INTERMEDIATE_DAYS -notext -md sha256 \
  -in $INTERMEDIATE_DIR/csr/intermediate.csr.pem \
  -out $INTERMEDIATE_DIR/certs/intermediate.cert.pem

chmod 444 $INTERMEDIATE_DIR/certs/intermediate.cert.pem

echo -e "${RED}Intermediate CA verify: ${SET}"
openssl x509 -noout -text \
  -in $INTERMEDIATE_DIR/certs/intermediate.cert.pem

echo -e "${RED}Verify intermediate CA: ${SET}"
openssl verify -CAfile $ROOT_DIR/certs/ca.cert.pem \
  $INTERMEDIATE_DIR/certs/intermediate.cert.pem

cat $INTERMEDIATE_DIR/certs/intermediate.cert.pem \
  $ROOT_DIR/certs/ca.cert.pem > $INTERMEDIATE_DIR/certs/ca-intermediate-chain.cert.pem
chmod 444 $INTERMEDIATE_DIR/certs/ca-intermediate-chain.cert.pem

openssl x509 -outform der -in $ROOT_DIR/certs/ca.cert.pem -out $ROOT_DIR/certs/ca.cert.crt
chmod 444 $ROOT_DIR/certs/ca.cert.crt

openssl x509 -outform der -in $INTERMEDIATE_DIR/certs/intermediate.cert.pem -out $INTERMEDIATE_DIR/certs/intermediate.cert.crt
chmod 444 $INTERMEDIATE_DIR/certs/intermediate.cert.crt

cp $ROOT_DIR/certs/ca.cert.pem $PUBLIC_DIR/root-ca.pem
cp $ROOT_DIR/certs/ca.cert.crt $PUBLIC_DIR/root-ca.crt

cp $INTERMEDIATE_DIR/certs/intermediate.cert.pem $PUBLIC_DIR/intermediate-ca.pem
cp $INTERMEDIATE_DIR/certs/intermediate.cert.crt $PUBLIC_DIR/intermediate-ca.crt
chmod 444 $PUBLIC_DIR/*

if [ "$CA_DEV" == "1" ]; then
  cd $PROJECT_PATH
  rm -rf *.tgz
  tar -czf ca.tgz certs output
fi
