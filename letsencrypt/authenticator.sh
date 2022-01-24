#!/bin/bash

SITE=$1
DIR=.well-known/acme-challenge
USER=$2
TMPPWDFILE=$3
PWD=$(cat $TMPPWDFILE)

mkdir --parents $DIR
echo $CERTBOT_VALIDATION > $DIR/$CERTBOT_TOKEN

RDIR=(${DIR//// })

ftp -inv $SITE <<EOF
user $USER $PWD
cd /
mkdir ${RDIR[0]}
mkdir ${RDIR[0]}/${RDIR[1]}
mput $DIR/$CERTBOT_TOKEN
bye
EOF

exit 0
