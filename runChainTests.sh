#!/bin/sh

#CERTTOOL="${CERTTOOL:-../../../src/certtool${EXEEXT}}"
CERTTOOL=/home/mukrop/work/gnutls/src/certtool
OUTPUT=out
CHAINFILE=chain.pem

CREATECHAIN=./createChain.sh

if [ $# -eq 0 ]
then
    echo "Script for testing certificate chains using certool"
	echo "usage: $0 <chain1.pem> [<chain2.pem> ...]"
    echo "dependency: createChain.sh"
    echo "temporary dir for results (will be deleted!): ${OUTPUT}"
    echo "certtool used: ${CERTTOOL}"
	exit -1
fi

if [ ! -x ${CREATECHAIN} ]
then
    echo "Error: Script for creating chains not present or not executable (${CREATECHAIN})."
    exit -1
fi

rm -rf ${OUTPUT}
mkdir -p ${OUTPUT}

for CHAIN in $@
do
    if [ ! -f ${CHAIN} ]
    then
        echo "Warning: Chainfile not present or not readable (${CHAIN})."
        continue
    fi
    DESCRIPTION=`cat ${CHAIN} | grep -e "^description:" | sed 's/^description: \(.*\)$/\1/'`
    EXPECTED_OUTCOME=`cat ${CHAIN} | grep -e "^expected-outcome:" | sed 's/^expected-outcome: \(.*\)$/\1/'`
    OUTPUT=${OUTPUT} CERTTOOL=${CERTTOOL} CHAINFILE=${CHAINFILE} ${CREATECHAIN} $CHAIN
    ${CERTTOOL} --verify-chain --infile ${OUTPUT}/${CHAINFILE} >/dev/null
    OUTCOME=$?
    echo "=== ${CHAIN}: ${DESCRIPTION} ==="
    echo "expected: ${EXPECTED_OUTCOME}"
    echo "real: ${OUTCOME}"
done
