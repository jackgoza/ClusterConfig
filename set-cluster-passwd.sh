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
  echo '      Usage: ./set-cluster-passwd.sh <cluster-addresses> <username> <password> <num_slaves> <privateKey>'
  echo "    Example: ./set-cluster-passwd.sh cluster-machines.txt anask myPa$$ 15 /Users/anask/.ssh/cloud_lab\n"
  echo "      Notes: - first line in <cluster-addresses> contains master node address."
  echo "             - using hard-coded names ($MSTR, $SLVPREFX)."
  exit 1
fi


MLIST=$1
USRNM=$2
PASS=$3
NUMSLVS=$4
KEY=$5
M=0
MSTRADD=address

echo "Setting cluster password.."
while read ADDR
do
  if [ "$M" -eq 0 ]; then
    ssh -o "StrictHostKeyChecking no" -i $KEY  $USRNM@$ADDR "export DEBIAN_FRONTEND='noninteractive' && sudo apt-get install sshpass --yes > /dev/null && exit" < /dev/null
    MSTRADD="$ADDR"
    echo $MSTRADD
  fi
  scp -o "StrictHostKeyChecking no" -i $KEY  instance-setup.sh $USRNM@$ADDR:~/
  ssh -o "StrictHostKeyChecking no" -i $KEY  $USRNM@$ADDR "echo  -e '$PASS\n$PASS' | sudo passwd $USRNM && sudo chmod +x ~/instance-setup.sh && exit" < /dev/null

  M=$((M+1))
done <<< "$(cat $MLIST)"

echo "generate and copy rsa key for master to slaves"
ssh -o "StrictHostKeyChecking no" -i $KEY  $USRNM@$MSTRADD "
    # copy to local user
    ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
    ssh-keyscan -H $MSTR >> ~/.ssh/known_hosts
    sshpass -p $PASS ssh-copy-id $USRNM@$MSTR

    # copy to localhost
    ssh-keyscan -H 0.0.0.0 >> ~/.ssh/known_hosts
    sshpass -p $PASS ssh-copy-id $USRNM@0.0.0.0
    
    # make all hosts (including slaves) known
    ssh-keyscan -f /etc/hosts >> ~/.ssh/known_hosts

    # copy to slaves
    s=1
    while [[ \$s -le $NUMSLVS ]];
    do
	sshpass -p $PASS ssh-copy-id $USRNM@$SLVPREFX-\$s
	s=\$((s+1))
    done
    chmod 0600 ~/.ssh/authorized_keys
" < /dev/null
echo "Done."

