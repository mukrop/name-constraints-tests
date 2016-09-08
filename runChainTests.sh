#!/bin/sh

# Tools and binaries
#GNUTLS_CERTTOOL="${GNUTLS_CERTTOOL:-../../../src/certtool${EXEEXT}}"
GNUTLS_CERTTOOL=/home/mukrop/work/gnutls/src/certtool
NSS_CERTUTIL=`which certutil`
OPENSSL_BIN=`which openssl`

# Directories
WORKDIR=tmp
CERTDIR=${WORKDIR}/certs

# Filenames
CHAINFILE=chain.pem

# Scripts
CREATECHAIN=./createChain.sh

if [ $# -eq 0 ]
then
    echo "Script for validating certificate chains generated from GnuTLS templates using GnuTLS, NSS and OpenSSL."
	echo "usage: $0 <chain1.tmpl> [<chain2.tmpl> ...]"
    echo
    echo "dependency: ${CREATECHAIN}"
    echo "temporary dir for results (will be deleted!): ${WORKDIR}"
    echo "GNUTLS_CERTTOOL used: ${GNUTLS_CERTTOOL}"
    echo "NSS_CERTUTIL used: ${NSS_CERTUTIL}"
    echo "OPENSSL_BIN used: ${OPENSSL_BIN}"
	exit -1
fi

if [ ! -x ${CREATECHAIN} ]
then
    echo "Error: Script for creating chains not present or not executable (${CREATECHAIN})."
    exit -1
fi

rm -rf ${WORKDIR}
mkdir -p ${WORKDIR}

printf '%-20s %-8s | %-7s %-7s %-7s | %s\n' "" Expected GnuTLS NSS OpenSSL "Test description"

for CHAIN in $@
do
    if [ ! -f ${CHAIN} ]
    then
        echo "Warning: Chainfile not present or not readable (${CHAIN})."
        continue
    fi

    # Create chain from template
    DESCRIPTION=`cat ${CHAIN} | grep -e "^description:" | sed 's/^description: \(.*\)$/\1/'`
    OUTCOME_EXPECTED=`cat ${CHAIN} | grep -e "^expected-outcome:" | sed 's/^expected-outcome: \(.*\)$/\1/'`
    if [ ${OUTCOME_EXPECTED} = "PASS" ]
    then
        OUTCOME_EXPECTED=OK
    else
        OUTCOME_EXPECTED=FAIL
    fi
    OUTPUT=${CERTDIR} CERTTOOL=${GNUTLS_CERTTOOL} CHAINFILE=${CHAINFILE} ${CREATECHAIN} ${CHAIN}

    # GnuTLS
    OUTPUT_GNUTLS=$(${GNUTLS_CERTTOOL} --verify-chain --infile ${CERTDIR}/${CHAINFILE} 2>&1)
    if [ $? -eq 0 ]
    then
        OUTCOME_GNUTLS=OK
    else
        OUTCOME_GNUTLS=FAIL
    fi

    # NSS
    PASSWORDFILE=${WORKDIR}/passwd
    echo "password" >${PASSWORDFILE}
    NSS_DB=${WORKDIR}/nss-db
    rm -rf ${NSS_DB}
    mkdir ${NSS_DB}
    ${NSS_CERTUTIL} -N -d ${NSS_DB} -f ${PASSWORDFILE}
    #${NSS_CERTUTIL} -L -d ${NSS_DB}
    ${NSS_CERTUTIL} -A -n ${CERTDIR}/0.pem -t "CT,," -i ${CERTDIR}/0.pem -d ${NSS_DB}
    for CERT in ${CERTDIR}/[1-9].pem
    do
        #${NSS_CERTUTIL} -L -d ${NSS_DB}
        ${NSS_CERTUTIL} -A -n ${CERT} -t ",," -i ${CERT} -d ${NSS_DB}
    done
    #${NSS_CERTUTIL} -L -d ${NSS_DB}
    #${NSS_CERTUTIL} -O -n ${CERT} -d ${NSS_DB} -f passwd
    OUTPUT_NSS=$(${NSS_CERTUTIL} -V -n ${CERT} -u C -e -l -d ${NSS_DB} -f ${PASSWORDFILE} 2>&1)
    RETURN_NSS=$?
    if [ ${RETURN_NSS} -eq 0 ]
    then
        OUTCOME_NSS=OK
    else
        OUTCOME_NSS=FAIL
    fi

    # OpenSSL
    OUTPUT_OPENSSL=$(${OPENSSL_BIN} verify -verbose -trusted ${CERTDIR}/0.pem -untrusted ${CERTDIR}/chain.pem ${CERT} 2>&1)
    if [ $? -eq 0 ]
    then
        OUTCOME_OPENSSL=OK
    else
        OUTCOME_OPENSSL=FAIL
    fi

    printf '%-20s %-8s | %-7s %-7s %-7s | %s\n' `basename ${CHAIN}` ${OUTCOME_EXPECTED} ${OUTCOME_GNUTLS} ${OUTCOME_NSS} ${OUTCOME_OPENSSL} "${DESCRIPTION}"
    if [ 0$DEBUG -gt 0 ]
    then
        echo "GnuTLS:  ${OUTPUT_GNUTLS}"
        echo "NSS:     ${OUTPUT_NSS}"
        echo "OpenSSL: ${OUTPUT_OPENSSL}"
    fi
done

rm -rf nss-db
