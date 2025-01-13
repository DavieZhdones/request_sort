#!/usr/bin/env bash
# filename: request_sort.sh
# author: @AntonenkovArt

# TODO:
# 1 - проверить, работают ли команды с || для PEM или DER
# 3 - раскомментировать получение пути из входного аргумента
# 4 - раскомментировать копирование сертификата с новым названием
# 5 - раскомментировать создание директории при проверки её существования

###Variables###
certs_path="/Users/artemantonenkov/Downloads"

#if [[ ! "${1}" ]]; then
#	Logger "ERROR" "Path to certs was not provided"
#	exit 1
#else
#	Logger "INFO" "Used path to certs: ${1}"
#fi

#certs_path="${1}"

###Methods###

#Logging method - on input: type ("DEBUG" | "INFO" |  "WARNING" | "ERROR"); message (any str)
Logger () {
	date=$(date)
	type="${1}"
	message="${2}"
	echo "[${date}]:[${type}]: ${message}" | tee -a sort.log
}

#Method for checking existance of directory by path on input
#Creating dir if it does not exist
CheckDirExistance () {
	path=$1
	if [[ ! -d "${path}" ]]; then
		Logger "WARNING" "There is no dir ${path}"
		Logger "WARNING" "Creating directory ${path}"
		#mkdir "${path}"
	else
		Logger "INFO" "There is dir ${path}"
	fi
}

###Main###
#Get cert array from directory by name pattern "*.pem" "*.cer" "*.crt" "*.p10"
cert_array=$(find "${certs_path}" \( -name "*.pem" -o -name "*.cer" -o -name "*.crt" -o -name "*.p10" \) -execdir basename '{}' ';' | sort -V)

#Iterating over cert array to identificate it and put into directory
for cert in $cert_array; do
	Logger "INFO" "Checking ${cert}"
	
	#Getting certificate CN field - for PEM or DER
	cert_CN=$(openssl x509 -in "${certs_path}"/"${cert}" -noout -subject -nameopt multiline 2>>/dev/null | awk -F' = ' '/commonName/ {print $2}' || openssl x509 -in "${certs_path}"/"${cert}" -inform DER -noout -subject -nameopt multiline 2>>/dev/null | awk -F' = ' '/commonName/ {print $2}')
	
	#Check cert type - RSA or GOST or file is not certificate
	if [[ "${cert_CN}" ]]; then
		if [[ $(grep "\-\-\-\-\-BEGIN CERTIFICATE\-\-\-\-\-" "${certs_path}"/"${cert}") ]] && [[ $(grep "\-\-\-\-\-END CERTIFICATE\-\-\-\-\-" "${certs_path}"/"${cert}") ]]; then
			#echo "CERT IS PEM"
			cert_type="RSA"
		else
			#echo "CERT IS DER"
			cert_type="GOST"
		fi
	else
		Logger "WARNING" "File ${certs_path}/${cert} is not cert, skip it"
		echo "======================================================================="
		continue
	fi

	#Check if CN is empty - then error
	if [[ ! "${cert_CN}" ]]; then
		Logger "WARNING" "No CN field in ${cert}, skip it"
		echo "======================================================================="
		continue
	fi

	#Cert name is forming by using cert CN field
	cert_name="${cert_CN}.cer"
	Logger "INFO" "New cert name is ${cert_name}"

	#Getting cert start date
	cert_startdate=$(openssl x509 -in "${certs_path}"/"${cert}" -startdate -noout | awk -F'=' '{print $2}' || openssl x509 -in "${certs_path}"/"${cert}" -inform DER -startdate --noout | awk -F'=' '{print $2}')
	
	#Separating cert start date to year, quarter, month, day
	cert_year=$(echo "${cert_startdate}" | awk -F' ' '{print $4}')
	case ${cert_month} in
		Jan|Feb|Mar)
		cert_quarter="1"
		;;
		Apr|May|Jun)
		cert_quarter="2"
		;;
		Jul|Aug|Sep)
		cert_quarter="3"
		;;
		Oct|Nov|Dec)
		cert_quarter="4"
		;;
	esac
	cert_month=$(echo "${cert_startdate}" | awk -F' ' '{print $1}')
	cert_day=$(echo "${cert_startdate}" | awk -F' ' '{print $2}')

	#Forming cert path out of year, quarter, month, day
	cert_path=("${cert_type}" "${cert_year}" "${cert_quarter}" "${cert_month}" "${cert_day}")

	#Set current path empty - because in the end of iteration it will contain full path
	#
	current_path=''
	for directory in "${cert_path[@]}"; do
		current_path+="${directory}"/
		echo "CURRENT PATH IS:" "${current_path}"
		CheckDirExistance "${current_path}"
	done

	#Coping cert into it final path
	Logger "INFO" "Coping cert ${cert_name} into ${current_path}"
	#cp "${certs_path}"/"${cert}" "${current_path}""${cert_name}"
	echo "======================================================================="
done
