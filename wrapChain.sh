#!/bin/bash

HEADER="\
/* TODO: Short chain description */
static const char *nc_badX[] = {"
FOOTER="\
  NULL
};"
COMMENT="\
  /* Name Constraints (critical):
    Permitted: IPAddress: 172.23.122.0/24
    Excluded:  IPAddress: 172.23.122.0/24 */"

if [ $# -eq 0 ]
then
    echo "usage: "$0" <cert.pem> [ <cert.pem> ... ]"
    exit -1
fi

echo -e "$HEADER"
for CERT in $@
    do
    echo -e "$COMMENT"
    head -c -1 $CERT | sed 's/^/  "/' | sed 's/$/\\n"'/
    echo ','
    done
echo -e "$FOOTER"
