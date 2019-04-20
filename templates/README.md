# $INFRASTRUCTURE_NAME Infrastructure Security Guide

Hello dear $CLIENT_NAME ($CLIENT_USER).

## Install root ca

\`\`\`bash
sudo cp .$INFRASTRUCTURE_NS/.$INFRASTRUCTURE_NS-certificate.crt /usr/local/share/ca-certificates/aasaam.crt
sudo update-ca-certificates
\`\`\`

### Your ssh public keys

RSA:

\`\`\`txt
$SSH_RSA_PUB
\`\`\`

ED25519:

\`\`\`txt
$SSH_ED25519_PUB
\`\`\`

### Your gpg public key:

\`\`\`txt
$PGP_PUBLIC_KEY
\`\`\`

## Change ssh passphrase

\`\`\`bash
ssh-keygen -p -f .ssh/id_rsa
sh-keygen -p -f .ssh/id_ed25519
\`\`\`

## Change gpg passphrase

\`\`\`bash
gpg --edit-key $PGP_KEY_ID
\`\`\`

Then inside gpg cli type, it will ask old password and you can type new password.

\`\`\`txt
> passwd
\`\`\`

After done
\`\`\`txt
> quit
\`\`\`
