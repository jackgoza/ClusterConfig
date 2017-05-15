#!/bin/bash
#
#
# Note: If you’re asked for a password during the execution, the machine that
# is being contacted might not have been started properly.
# To check it, log in to the machine through the CloudLab shell and make
# sure it is running and reload it if it is not running properly
# (from the topology/list view).
#
#

MSTR='ctl'
SLVPREFX='cp'


if [ "$#" -ne 5 ]; then
  echo ""
  echo '      Usage: ./set-cluster-passwd.sh <cluster_addresses> <username> <password> <num_slaves> <private_key>'
  echo -e "    Example: ./set-cluster-passwd.sh cluster-machines.txt anask myPa$$ 15 /Users/anask/.ssh/cloud_lab\n"
  echo "      Notes: - first line in <cluster-addresses> contains master node address."
  echo -e "             - $0 is using hard-coded names ($MSTR, $SLVPREFX).\n"
  exit 1
fi


MLIST=$1
USRNM=$2
PASS=$3
NUMSLVS=$4
KEY=$5
M=0
MSTRADD=address
NO_HSTFILE=()
NO_HSTNM=()

echo "Setting cluster password.."
while read ADDR
do
  echo "Setting up machine: $ADDR"
  if [ "$M" -eq 0 ]; then
    ssh -o "StrictHostKeyChecking no" -i $KEY  $USRNM@$ADDR "export DEBIAN_FRONTEND='noninteractive' && sudo apt-get install sshpass --yes > /dev/null && exit" < /dev/null
    MSTRADD="$ADDR"
  fi

  # copy setup file
  scp -o "StrictHostKeyChecking no" -i $KEY  instance-setup.sh $USRNM@$ADDR:~/

  # change password and make setup file executable
  ssh -o "StrictHostKeyChecking no" -i $KEY  $USRNM@$ADDR "echo  -e '$PASS\n$PASS' | sudo passwd $USRNM && sudo chmod +x ~/instance-setup.sh && exit" < /dev/null

  # check if machine has a hostname
  CHECK_HSTNM=$(ssh -o "StrictHostKeyChecking no" -i $KEY  $USRNM@$ADDR '
    if [ ! -f  /etc/hostname ]; then
       exit 1
    fi
    HSTNAME=$(cat /etc/hostname)
    HSTNAME_LEN=${#HSTNAME}
    if [ "$HSTNAME_LEN" -eq "0" ]; then
       exit 2
    fi
    exit 0
   ' < /dev/null)

  CHECK_HSTNM_STS=$(echo $?)
  # status either 0, 1, or 2

  if [ "$CHECK_HSTNM_STS" -eq "1" ]; then
    NO_HSTFILE+=("$ADDR")
  fi

  if [ "$CHECK_HSTNM_STS" -eq "2" ]; then
    NO_HSTNM+=("$ADDR")
  fi

  M=$((M+1))
done <<< "$(cat $MLIST)"

echo ""
EXT=0
if [ "${#NO_HSTFILE[@]}" -ne "0" ]; then
   echo "ERORR:"
   echo "  The file \"/etc/hostname\" was not found in the machine(s) below."
   echo "  Possible machine boot error. Reload the machine(s) then assign"
   echo "  a hostname in /etc/hostname."
   echo -e "  Example: echo \"cp-1.test1.project.utah.cloudlab.us\" > /etc/hostname\n"
   printf '  %s\n' "${NO_HSTFILE[@]}"
   echo ""
   EXT=1
fi
if [ "${#NO_HSTNM[@]}" -ne "0" ]; then
   echo "ERROR:"
   echo "  No hostname defined in \"/etc/hostname\" in the machine(s) below."
   echo "  Set a hostname.";
   echo -e "  Example: echo \"ctl.test1.project.utah.cloudlab.us\" > /etc/hostname\n"
   printf '  %s\n' "${NO_HSTNM[@]}"
   echo ""
   EXT=1
fi

if [ $EXT -eq 1 ]; then
   exit 0
fi

echo "generate and copy rsa key for master to slaves"
ssh -o "StrictHostKeyChecking no" -i $KEY  $USRNM@$MSTRADD "
    # copy to local user
    ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
    ssh-keyscan -H $MSTR >> ~/.ssh/known_hosts
    sudo sshpass -p $PASS ssh-copy-id $USRNM@$MSTR

    # copy to 0.0.0.0 and localhost
    ssh-keyscan -H 0.0.0.0 >> ~/.ssh/known_hosts
    sudo sshpass -p $PASS ssh-copy-id $USRNM@0.0.0.0

    ssh-keyscan -H localhost >> ~/.ssh/known_hosts
    sudo sshpass -p $PASS ssh-copy-id $USRNM@localhost


    # make all hosts (including slaves) known
    ssh-keyscan -f /etc/hosts >> ~/.ssh/known_hosts

    # copy to slaves
    s=1
    while [[ \$s -le $NUMSLVS ]];
    do
	sudo sshpass -p $PASS ssh-copy-id $USRNM@$SLVPREFX-\$s
	s=\$((s+1))
    done
    chmod 0600 ~/.ssh/authorized_keys
" < /dev/null
echo "Done."

