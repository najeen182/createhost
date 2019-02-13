#!/bin/bash
#Author: Najeen Nepali
#Created at: 12 Feb 2019
#Purpose : Creating Virtual Host For Passed Domain Name


APACHE_DIR="/etc/apache2/sites-available/"
APACHE_SITESENABLED_DIR="/etc/apache2/sites-enabled/"
APACHE_WWW_DIR="/var/www/html/"
APACHE_LOG_DIR="/var/log/apache2/"
APACHE_SSL_DIR="/etc/apache2/ssl/"


function apacheControl(){
	case $1 in
	"start")
		systemctl start apache2
		;;
	"stop")
		systemctl stop apache2
		;;
	"restart")
		systemctl restart apache2
		;;
	"reload")
		systemctl reload apache2
		;;
	"status")
		systemctl is-active apache2
		;;

	"configtest")
		apacehctl configtest
		;;
	*)
		echo "Usage: {start|stop|restart|reload|status|configtest}"
		exit 1
	esac
}

function getCertificate(){
	#Check If Domain Exists or Not
	checkRecord=`dig +short ${1}`
	[ -z "${checkRecord}" ] && exit 1
	sudo certbot certonly --standalone --preferred-challenges http -d ${1}
}


function getCertBot(){
	echo "[+] Check If Cert Bot Is Installed Or Not..."
	which certbot > /dev/null
	if [[ $? -ne 0 ]];then
		echo -e "\t[+] CertBot Not Found..Installing It"
		sudo add-apt-repository ppa:certbot/certbot
		sudo apt-get update
		sudo apt-get -y install certbot
	fi
	echo -e "\t[+] CertBot Found..Skipping Installation.."

}

function generateVirtualHostConfig(){
	domainname=$1
cat << EOF
<VirtualHost ${domainname}.com:443>
	ServerAdmin server@${domainname}
	DocumentRoot ${APACHE_WWW_DIR}${domainname}
	ServerName ${domainname}
	SSLEngine on
	SSLCertificateFile ${APACHE_SSL_DIR}/${domainname}.crt
	SSLCertificateKeyFile ${APACHE_SSL_DIR}/${domainname}.key
	SSLCACertificateFile ${APACHE_SSL_DIR}/${domainname}.intermediate.crt
	ErrorLog ${APACHE_LOG_DIR}${domainname}-error.log
	CustomLog ${APACHE_LOG_DIR}/${domainname}-access.log common
	<Directory "${APACHE_WWW_DIR}${domainname}">
		DirectoryIndex index.html
		Options Indexes FollowSymLinks Includes MultiViews
		AllowOverride None
		Require all granted
		Order allow,deny
		Allow from all
	</Directory>
</VirtualHost>
EOF
}
function checkApacheServerExists(){
	echo -e "[+] Checking If Apache Server Exists or not"
	which apache2 > /dev/null
	if [[ $? -ne 0 ]];
		sudo apt-get -y install apache2
	fi
}

function main(){
	checkApacheServerExists
	if [[ -f ${APACHE_DIR}${1}.conf ]];then
		echo "Domain Already Exists.. Try new domain"
		exit 1
	fi
	getCertBot
	apachestatus=`apacheControl "status"`
	echo -e "\t Apache Status ... ${apachestatus}"
	if [[ ${apachestatus} == "active" ]];then
		echo -e "Stopping Apache"
		apacheControl "stop"
	fi
	if [[ ${apachestatus} == "inactive" ]];then
		#getCertificate $1
		echo -e "Generating Host Config File"
		generateVirtualHostConfig $1 > ${APACHE_DIR}${1}.conf
		if [[ -f ${APACHE_DIR}${1}.conf ]];then
			if [ ! -d ${APACHE_WWW_DIR}${1} ];then
				echo -e "Creating Host Directory"
				mkdir ${APACHE_WWW_DIR}${1}
			fi
			echo -e "Copying Default Html File to New Domain"
			cp ${PWD}/hello.html ${APACHE_WWW_DIR}${1}/hello.html
		fi
		echo -e "[+} Creating SymLink"
		ln -s ${APACHE_WWW_DIR}{$1}.conf ${APACHE_SITESENABLED_DIR} 

	fi
	
}
user=`whoami`
if [[ ${user} != 'root' ]];then
	echo "Run this Script as root"
	exit
fi

#Check If Argunent is Supplied or not
if [[ -z "$1" ]];then
	echo "<Usage> $0 <domainname>"
	exit 1
fi
main $1

