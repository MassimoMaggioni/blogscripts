#!/bin/bash

# user configuration
INI=./config.ini
SITE=ftp.a.com
USER=b

# functions
usage() {
	echo ""
	echo " Automation for site certificate "
	echo "================================="
	echo ""
	echo "This script support the following arguments:"
	echo ""
	echo -e "-h | --help \t This help"
  echo -e "-n | --new \t Request a new certificate"
	echo -e "-r | --renew \t Renew the current certificate"
	echo -e "-k | --revoke \t Revoke the current certificate"
	echo -e "-c | --clean \t Clean the certificate environment"
	echo -e "-v | --verbose \t Verbose output"
	echo ""
}

renew() {
	echo -e "Not implemented!"
}

new() {
	TMPPWDFILE=$(tempfile --directory ./)
	read -ers -p "FTP Site password: " PWD
	# certbot logs the arguments passed to the hooks, so save the password in a temp file and pass it to scripts
	# the name of the temp file will be logged, but not is content
	echo $PWD > $TMPPWDFILE
	certbot certonly $VERBOSE $TEST $DEBUG --manual-auth-hook "./authenticator.sh $SITE $USER $TMPPWDFILE" --manual-cleanup-hook "./cleanup.sh $SITE $USER $TMPPWDFILE" --config $INI
	rm $TMPPWDFILE
}

revoke() {
		certbot revoke $VERBOSE $TEST $DEBUG --config $INI --reason superseded --delete-after-revoke
}

clean() {
	# are you insane?
	echo ""
	echo "############################################"
	echo "#          --> DANGEROUS! <---             #"
	echo "# DO YOU WANT TO DELETE ALL THE STRUCTURE? #"
	echo "#  	  		YOU LOOSE EVERYTHING!            #"
	echo "############################################"

	read -r -p "Are you sure? [Yy/Nn] " answer
	case "$answer" in
		[Yy])
			echo "OK, you are insane"
			# read from configuration ini file
			CONF=$(awk -F "=" '/config-dir/ {print $2}' $INI)
			WORK=$(awk -F "=" '/work-dir/ {print $2}' $INI)
			LOGS=$(awk -F "=" '/logs-dir/ {print $2}' $INI)
			rm --recursive $CONF
			rm --recursive $WORK
			rm --recursive $LOGS
			;;
		[Nn])
			echo "Aborting"
			exit 1
			;;
		*)
			echo "Bad answer: aborting"
			exit 1
	esac
}

# Debug switch
DEBUG="--dry-run"

# switch default
VERBOSE=
TEST=

# number of arguments required
if [ "$#" -lt "1" ]; then
	usage
	exit 1
fi

# main
read -er -p  "Test? [Yy/Nn]: " TESTING
case "$TESTING" in
	[Yy])
		TEST="--test-cert"
	;;
	[Nn])
		TEST=
	;;
	*)
		echo "Bad answer: aborting"
		exit 1
esac

# parameters parsing
while [ "$1" != "" ]; do
	case "$1" in
		-h|--help)
				usage
	 			exit 0
				;;
		-v|--verbose)
				VERBOSE="--verbose"
				shift 1
				;;
		-n|--new)
				new
				shift 1
				;;
		-r|--renew)
				renew
				shift 1
				;;
		-k|--revoke)
				revoke
				shift 1
				;;
		-c|--clean)
				clean
				shift 1
				;;
		*|-*|--*=)
				echo "Error: unsupported argument $1"
				usage
				exit 1
	esac
done

exit 0
