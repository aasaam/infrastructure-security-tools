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
  rm -rf output certs
  tar -xf ca.tgz
fi

if [ -d "$SERVER_DIR" ]; then
  echo "Server directory exist. skipped."
  exit
fi

if [ "$CA_DEV" == "1" ] && [[ -v CA_DEV_PASS ]]; then
  ROOT_PASSWORD=$CA_DEV_PASS
  INT_PASSWORD=$CA_DEV_PASS
  SSH_PASSWORD=$CA_DEV_PASS
  SSH_PASSWORD2=$CA_DEV_PASS
else
  echo -e "${RED}Enter root ca password:${SET}"
  read -s ROOT_PASSWORD

  echo -e "${RED}Enter intermediate ca password:${SET}"
  read -s INT_PASSWORD

  echo -e "${RED}Enter SSH password:${SET}"
  read -s SSH_PASSWORD

  echo -e "${RED}Enter SSH password again:${SET}"
  read -s SSH_PASSWORD2
fi

if [ "$SSH_PASSWORD" != "$SSH_PASSWORD2" ]; then
  echo "Passphrase did not matched."
  exit
fi

mkdir -p $SERVER_DIR/private
mkdir -p $SERVER_DIR/certs
mkdir -p $SERVER_DIR/csr

cd $DATA_DIR
KEY_ALL_SIZES=( "2048" "4096")
CERT_INDEX=0
for INDEX in {0..9}
do
  for KEY_SIZE in "${KEY_ALL_SIZES[@]}"
  do
    POST_INDEX=$INDEX.$KEY_SIZE

    openssl genrsa \
      -out $SERVER_DIR/private/server_$POST_INDEX.key.pem $KEY_SIZE
    chmod 400 $SERVER_DIR/private/server_$POST_INDEX.key.pem

    openssl genrsa \
      -out $SERVER_DIR/private/server_internal_$POST_INDEX.key.pem $KEY_SIZE
    chmod 400 $SERVER_DIR/private/server_internal_$POST_INDEX.key.pem

    openssl genrsa \
      -out $SERVER_DIR/private/client_internal_$POST_INDEX.key.pem $KEY_SIZE
    chmod 400 $SERVER_DIR/private/client_internal_$POST_INDEX.key.pem

    SERVER_EXTENSION_INDEX="$SERVER_EXTENSION.$POST_INDEX"
    SERVER_INTERNAL_EXTENSION_INDEX="$SERVER_INTERNAL_EXTENSION.$POST_INDEX"
    CLIENT_INTERNAL_EXTENSION_INDEX="$CLIENT_INTERNAL_EXTENSION.$POST_INDEX"
    render_template $PROJECT_PATH/templates/openssl.server.conf.ini > $SERVER_EXTENSION_INDEX
    render_template $PROJECT_PATH/templates/openssl.server.internal.conf.ini > $SERVER_INTERNAL_EXTENSION_INDEX
    render_template $PROJECT_PATH/templates/openssl.client.internal.conf.ini > $CLIENT_INTERNAL_EXTENSION_INDEX

    openssl req -batch -config $SERVER_EXTENSION_INDEX \
      -key $SERVER_DIR/private/server_$POST_INDEX.key.pem \
      -new -sha256 -out $SERVER_DIR/csr/server_$POST_INDEX.csr.pem

    openssl req -batch -config $SERVER_INTERNAL_EXTENSION_INDEX \
      -key $SERVER_DIR/private/server_internal_$POST_INDEX.key.pem \
      -new -sha256 -out $SERVER_DIR/csr/server_internal_$POST_INDEX.csr.pem

    openssl req -batch -config $CLIENT_INTERNAL_EXTENSION_INDEX \
      -key $SERVER_DIR/private/client_internal_$POST_INDEX.key.pem \
      -new -sha256 -out $SERVER_DIR/csr/client_internal_$POST_INDEX.csr.pem

    faketime -f "$DATE_YEAR-01-01 00:00:00" openssl ca -batch -passin pass:"$INT_PASSWORD" -config $SERVER_EXTENSION_INDEX \
      -extensions server_cert -days $SERVER_DAYS -notext -md sha256 \
      -in $SERVER_DIR/csr/server_$POST_INDEX.csr.pem \
      -out $SERVER_DIR/certs/server_$POST_INDEX.cert.pem
    chmod 444 $SERVER_DIR/certs/server_$POST_INDEX.cert.pem

    faketime -f "$DATE_YEAR-01-01 00:00:00" openssl ca -batch -passin pass:"$ROOT_PASSWORD" -config $SERVER_INTERNAL_EXTENSION_INDEX \
      -extensions server_cert -days $SERVER_DAYS -notext -md sha256 \
      -in $SERVER_DIR/csr/server_internal_$POST_INDEX.csr.pem \
      -out $SERVER_DIR/certs/server_internal_$POST_INDEX.cert.pem
    chmod 444 $SERVER_DIR/certs/server_internal_$POST_INDEX.cert.pem

    faketime -f "$DATE_YEAR-01-01 00:00:00" openssl ca -batch -passin pass:"$ROOT_PASSWORD" -config $CLIENT_INTERNAL_EXTENSION_INDEX \
      -extensions server_client_cert -days $SERVER_DAYS -notext -md sha256 \
      -in $SERVER_DIR/csr/client_internal_$POST_INDEX.csr.pem \
      -out $SERVER_DIR/certs/client_internal_$POST_INDEX.cert.pem
    chmod 444 $SERVER_DIR/certs/client_internal_$POST_INDEX.cert.pem

    echo -e "${RED}Domain Server CA verify: ${SET}"

    openssl x509 -noout -text \
      -in $SERVER_DIR/certs/server_$POST_INDEX.cert.pem

    openssl x509 -noout -text \
      -in $SERVER_DIR/certs/server_internal_$POST_INDEX.cert.pem

    openssl x509 -noout -text \
      -in $SERVER_DIR/certs/client_internal_$POST_INDEX.cert.pem

    echo -e "${RED}Domain Server CA verify via chain CA: ${SET}"

    cat $SERVER_DIR/certs/server_$POST_INDEX.cert.pem \
      $INTERMEDIATE_DIR/certs/intermediate.cert.pem > $SERVER_DIR/certs/server_$POST_INDEX.chain.cert.pem

    cat $SERVER_DIR/certs/server_internal_$POST_INDEX.cert.pem \
      $ROOT_DIR/certs/ca.cert.pem > $SERVER_DIR/certs/server_internal_$POST_INDEX.chain.cert.pem

    cat $SERVER_DIR/certs/server_internal_$POST_INDEX.cert.pem \
      $SERVER_DIR/private/server_internal_$POST_INDEX.key.pem > $SERVER_DIR/private/server_internal_$POST_INDEX.key-chain.cert.pem

    chmod 600 $SERVER_DIR/private/server_internal_$POST_INDEX.key-chain.cert.pem

    openssl verify -CAfile $INTERMEDIATE_DIR/certs/ca-intermediate-chain.cert.pem \
      $SERVER_DIR/certs/server_$POST_INDEX.chain.cert.pem

    openssl verify -CAfile $ROOT_DIR/certs/ca.cert.pem \
      $SERVER_DIR/certs/server_internal_$POST_INDEX.chain.cert.pem

    CERT_INDEX=$((CERT_INDEX + 1))
  done
done

openssl genrsa \
  -out $SERVER_DIR/private/server_local.key.pem 1024
chmod 400 $SERVER_DIR/private/server_local.key.pem

render_template $PROJECT_PATH/templates/openssl.server.local.conf.ini > $SERVER_LOCAL_EXTENSION

openssl req -batch -config $SERVER_LOCAL_EXTENSION \
  -key $SERVER_DIR/private/server_local.key.pem \
  -new -sha256 -out $SERVER_DIR/csr/server_local.csr.pem

faketime -f "$DATE_YEAR-01-01 00:00:00" openssl ca -batch -passin pass:"$INT_PASSWORD" -config $SERVER_LOCAL_EXTENSION \
  -extensions server_cert -days $SERVER_DAYS -notext -md sha256 \
  -in $SERVER_DIR/csr/server_local.csr.pem \
  -out $SERVER_DIR/certs/server_local.cert.pem
chmod 444 $SERVER_DIR/certs/server_local.cert.pem

openssl x509 -noout -text \
  -in $SERVER_DIR/certs/server_local.cert.pem

cat $SERVER_DIR/certs/server_local.cert.pem \
  $INTERMEDIATE_DIR/certs/intermediate.cert.pem > $SERVER_DIR/certs/server_local.chain.cert.pem

cat $SERVER_DIR/certs/server_local.cert.pem \
  $SERVER_DIR/private/server_local.key.pem > $SERVER_DIR/private/server_local.key-chain.cert.pem

openssl verify -CAfile $INTERMEDIATE_DIR/certs/ca-intermediate-chain.cert.pem \
  $SERVER_DIR/certs/server_local.chain.cert.pem

echo -e "${RED}SSH: ${SET}"
echo -e "${CYAN}Generating...${SET}"
mkdir -p $SERVER_OUT/.ssh
ssh-keygen -t rsa -b 4096 -C "$INFRASTRUCTURE_EMAIL" -q -N "" -f $SERVER_OUT/.ssh/id_rsa
ssh-keygen -t ed25519 -a 100 -C "$INFRASTRUCTURE_EMAIL" -q -N "" -f $SERVER_OUT/.ssh/id_ed25519
chmod 700 $SERVER_OUT/.ssh
echo -e "${GREEN}Done.${SET}"

chmod 400 $SERVER_DIR/private/*
chmod 444 $SERVER_DIR/certs/*

mkdir -p $SERVER_OUT

cp -rf $SERVER_DIR/certs $SERVER_OUT/
cp -rf $SERVER_DIR/private $SERVER_OUT/
