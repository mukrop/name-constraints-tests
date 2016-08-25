#!/bin/sh

#CERTTOOL="${CERTTOOL:-../../../src/certtool${EXEEXT}}"
CERTTOOL=${CERTTOOL:=/home/mukrop/work/gnutls/src/certtool}
OUTPUT=${OUTPUT:=out}
CHAINFILE=${CHAINFILE:=chain.pem}

TMPTEMPLATE=${OUTPUT}/template.tmp

if [ $# -eq 0 ]
then
    echo "Script for generating certificate chains using certool"
	echo "usage: $0 <chain-template-file>"
    echo "temporary dir for results (will be deleted!): ${OUTPUT} (can be taken from OUTPUT)"
    echo "final chain will be saved to: ${CHAINFILE} (can be taken from CHAINFILE)"
    echo "certtool used: ${CERTTOOL} (can be taken from CERTTOOL)"
	exit -1
fi

TEMPLATE=$1

if [ ! -f ${TEMPLATE} ]
then
    echo "Error: File ${TEMPLATE} does not exist or is not readable."
    exit -1
fi

MAXID=`cat ${TEMPLATE} | grep -e "^[0-9]:" | sort -r | head -1 | sed 's/^\([0-9]\).*$/\1/'`
if [ "${MAXID}" = "" ]
then
    echo "Error: Could not determine maximum certificate number."
    exit -1
fi

rm -rf "${OUTPUT}"
mkdir -p "${OUTPUT}"

for ID in `seq 0 ${MAXID}`
do
    cat ${TEMPLATE} | grep -e "^${ID}:" | sed 's/^[0-9]:\(.*\)$/\1/' >${TMPTEMPLATE}
    TEMPLATELINES=`cat ${TMPTEMPLATE} | wc -l`
    if [ ${TEMPLATELINES} -eq 0 ]
    then
        continue
    fi
	"${CERTTOOL}" --generate-privkey >"${OUTPUT}/${ID}.key" 2>/dev/null

	if [ ${ID} -eq 0 ] # Root CA
    then
		"${CERTTOOL}" --generate-self-signed --load-privkey "${OUTPUT}/${ID}.key" --outfile \
			"${OUTPUT}/${ID}.pem" --template "${TMPTEMPLATE}" 2>/dev/null
        if [ ! $? -eq 0 ]
        then
            echo "Error: Could not generate certificate for root CA (ID: ${ID})"
            exit -2
        fi
#		"${CERTTOOL}" --generate-crl --load-ca-privkey "${OUTPUT}/${name}.key" --load-ca-certificate "${OUTPUT}/${name}.pem" --outfile \
#			"${OUTPUT}/${name}.crl" --template "${TEMPLATE}" 2>/dev/null
    else
        "${CERTTOOL}" --generate-certificate --load-privkey "${OUTPUT}/${ID}.key" \
            --load-ca-certificate "${OUTPUT}/${PREV_ID}.pem" \
            --load-ca-privkey "${OUTPUT}/${PREV_ID}.key" \
            --outfile "${OUTPUT}/${ID}.pem" --template "${TMPTEMPLATE}" 2>/dev/null
        if [ ! $? -eq 0 ]
        then
            echo "Error: Could not generate certificate (ID: ${ID})"
            exit -2
        fi
    fi
    "${CERTTOOL}" --certificate-info --infile "${OUTPUT}/${ID}.pem" \
        --outfile "${OUTPUT}/${ID}.pem.info" 2>/dev/null
    if [ ! $? -eq 0 ]
    then
        echo "Warning: Could not generate info file for certificate (ID: ${ID})"
    fi
	PREV_ID=${ID}
done

rm ${TMPTEMPLATE}

for ID in `seq ${MAXID} -1 0`
do
    if [ ! -f "${OUTPUT}/${ID}.pem" ]
    then
        continue
    fi
	cat "${OUTPUT}/${ID}.pem" >> "${OUTPUT}/${CHAINFILE}"
done

"${CERTTOOL}" --certificate-info --infile "${OUTPUT}/${CHAINFILE}" \
    --outfile "${OUTPUT}/${CHAINFILE}.info" 2>/dev/null
