#!/bin/bash

SITE=$1
DIR=.well-known/acme-challenge
USER=$2
TMPPWDFILE=$3
PWD=$(cat $TMPPWDFILE)

RDIR=(${DIR//// })

ftp -inv $SITE <<EOF
user $USER $PWD
cd /
delete $DIR/$CERTBOT_TOKEN
rmdir ${RDIR[0]}/${RDIR[1]}
rmdir ${RDIR[0]}
bye
EOF

rm --recursive ${RDIR[0]}

exit 0
