#!/bin/bash
#==============================================================================
#
#          FILE:  script.sh
#
#         USAGE:  ./run-instance-setup.sh -a <addresses-file> -k <key-file> -p <cluster-password>
#
#   DESCRIPTION:

#
#
#   WARNING:
#   OPTIONS:      -a   a file that contains the public addresses of the machines
#                 -k   the private key file for connecting to the machines
#
#  REQUIREMENTS:  ---
#          BUGS:  ---
#         NOTES:  Must have an ssh public key stored on the machines.

#        AUTHOR:  Anas Katib, anaskatib@mail.umkc.edu
#   INSTITUTION:  University of Missouri-Kansas City
#       VERSION:  1.0
#       CREATED:  09/01/2017 11:30:00 AM CST
#      REVISION:  ---
#
#==============================================================================




scriptname=$0

function usage {
    echo "USAGE:   $scriptname -a <addresses> -k <ssh-key> -u <username> -p <password>"
    echo "EXAMPLE: $scriptname -a cluster-machines.txt -k /Users/anask/.ssh/id_rsa -u anask -p Pas\$Wd"
    echo "  -a <addresses>  addresses of machines to set up."
    echo "  -k <ssh-key>    private ssh key to connect to the machines."
    echo "  -u <username>   username to access the machines."
    echo "  -p <password>   password that was setup for all the machines."
    echo "  -h              print this message"
    exit 1
}

function aparse {
while [[ $# > 0 ]] ; do
  case "$1" in
    -a)
      ADDRESSES=${2}
      shift
      ;;
    -k)
      KEY=${2}
      shift
      ;;
    -u)
      USR=${2}
      shift
      ;;
    -p)
      PASS=${2}
      shift
      ;;
  esac
  shift
done
}

set -e

if [[ ($# -eq 0) || ( "$1" == "-h") || ( $1 != "-a" ) || ( ${#2} -eq 0 ) || ( $3 != "-k" ) || ( ${#4} -eq 0 ) || ( $5 != "-u" ) || ( ${#6} -eq 0 ) || ( $7 != "-p" ) || ( ${#8} -eq 0 )  ]] ; then
    usage
    exit 1
fi

echo -n "CHECKING SUDO PRIVILEGES FOR "
echo $(whoami)".."
sudo echo -n ""

if [[  "$USER" == "root" ]]; then
    echo -e "\nError: Do not run script via sudo, but you must have sudo privileges."
    exit 1
fi
echo "OK"

aparse "$@"


echo -e "\nINITIALIZING SETUP.."


# remove white spaces, empty lines, and tabs
sed 's/ //g' $ADDRESSES > tmp.cm.1
awk 'NF'  tmp.cm.1  > tmp.cm.2
awk '{ gsub(/\t/, ""); print }' tmp.cm.2 > $ADDRESSES
rm tmp.cm.*



NUMSLVS=$(wc -l < $ADDRESSES | tr -d ' ') # how many machines
NUMSLVS=$((NUMSLVS-1)) # subtract one for the master

while read ADDRESS ; do
     if [[ ! -z "${ADDRESS/ //}" ]]; then
        printf '\tSETTING UP %s\n' "$ADDRESS"
        ssh -o "StrictHostKeyChecking no" -i $KEY $USR@$ADDRESS "~/instance-setup.sh -p $PASS -c NUMSLVS &> ~/setup-log.txt" &
     fi
done < $ADDRESSES

echo "WAITING FOR SETUP TO FINISH.."
wait


echo "SETUP FINISHED."
exit 0
