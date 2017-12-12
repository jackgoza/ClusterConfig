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

# Git Attributes:
# git config --global core.editor "vim"
# git config --global user.name "Anas Katib"
# git config --global user.email anaskatib@mail.umkc.edu

MSTR='ctl'
SLVPREFX='cp'


if [ "$#" -lt 5 ]; then
  echo ""
  echo '      Usage: ./set-cluster-passwd.sh <cluster_addresses> <username> <password> <private_key> [verbose: 0 or 1]'
  echo -e "    Example: ./set-cluster-passwd.sh cluster-machines.txt anask myPa$$ /Users/anask/.ssh/cloud_lab 1\n"
  echo "      Notes: - first line in <cluster-addresses> contains master node address."
  echo -e "             - $0 is using hard-coded names ($MSTR, $SLVPREFX)."
  echo -e "             - if script freezes press CTRL + C to terminate the running command.\n"
  exit 1
fi


MLIST=$1
USRNM=$2
PASS=$3
KEY=$4
M=0
MSTRADD=address
NO_HSTFILE=()
NO_HSTNM=()

verbose=$5

exec 3>&1
exec 4>&2

if ((verbose)); then
  echo ""
else
  exec 1>/dev/null
  exec 2>/dev/null
fi

# remove white spaces, empty lines, and tabs
sed 's/ //g' $MLIST > tmp.cm.1
awk 'NF'  tmp.cm.1  > tmp.cm.2
awk '{ gsub(/\t/, ""); print }' tmp.cm.2 > $MLIST
rm tmp.cm.*

NUMSLVS=$(wc -l < $MLIST | tr -d ' ') # how many machines
NUMSLVS=$((NUMSLVS-1)) # subtract one for the master

echo "Setting cluster password.." 1>&3 2>&4


while read ADDR
do

  if [ "$M" -eq 0 ]; then
    MSTRADD="$ADDR"
    echo "Master address: "$MSTRADD 1>&3 2>&4
  fi
  echo "Setting up machine: $ADDR" 1>&3 2>&4

  # install sshpass
  ssh -o "StrictHostKeyChecking no" -i $KEY  $USRNM@$ADDR "export DEBIAN_FRONTEND='noninteractive' && sudo apt-get install sshpass --yes > /dev/null && exit" < /dev/null

  # copy setup file
  scp -o "StrictHostKeyChecking no" -i $KEY  instance-setup.sh $USRNM@$ADDR:~/

  # change password, make setup file executable, enable ssh password, and restart ssh
  ssh -o "StrictHostKeyChecking no" -i $KEY  $USRNM@$ADDR "echo  -e '$PASS\n$PASS' | sudo passwd $USRNM && sudo chmod +x ~/instance-setup.sh && sudo sed -i -- 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config && sudo service sshd restart && exit" < /dev/null

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
   echo "ERORR:" 1>&3 2>&4
   echo "  The file \"/etc/hostname\" was not found in the machine(s) below." 1>&3 2>&4
   echo "  Possible machine boot error. Reload the machine(s) then assign" 1>&3 2>&4
   echo "  a hostname in /etc/hostname." 1>&3 2>&4
   echo -e "  Example: echo \"cp-1.test1.project.utah.cloudlab.us\" > /etc/hostname\n" 1>&3 2>&4
   printf '  %s\n' "${NO_HSTFILE[@]}" 1>&3 2>&4
   echo "" 1>&3 2>&4
   EXT=1
fi
if [ "${#NO_HSTNM[@]}" -ne "0" ]; then
   echo "ERROR:" 1>&3 2>&4
   echo "  No hostname defined in \"/etc/hostname\" in the machine(s) below." 1>&3 2>&4
   echo "  Set a hostname."; 1>&3 2>&4
   echo -e "  Example: echo \"ctl.test1.project.utah.cloudlab.us\" > /etc/hostname\n" 1>&3 2>&4
   printf '  %s\n' "${NO_HSTNM[@]}" 1>&3 2>&4
   echo "" 1>&3 2>&4
   EXT=1
fi

if [ $EXT -eq 1 ]; then
   exit 0
fi

echo -e '\nConfiguring ssh keys..' 1>&3 2>&4
MACHINES=`cat $MLIST`
MACHINENNUM=0
for M in $MACHINES; do
   echo "--------------"
   echo "Generate and copy rsa key for $M to master and peers" 1>&3 2>&4
   echo "--------------"
   ssh -o "StrictHostKeyChecking no" -i $KEY  $USRNM@$M "

    # copy to local user
    rm -f ~/.ssh/id_rsa
    ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
    ssh-keyscan -H $MSTR >> ~/.ssh/known_hosts
    sshpass -p $PASS ssh-copy-id $USRNM@$M

    # copy to 0.0.0.0 and localhost
    ssh-keyscan -H 0.0.0.0 >> ~/.ssh/known_hosts
    sshpass -p $PASS ssh-copy-id $USRNM@0.0.0.0

    ssh-keyscan -H localhost >> ~/.ssh/known_hosts
    sshpass -p $PASS ssh-copy-id $USRNM@localhost

    # make all hosts (including slaves) known
    cat /etc/hosts > ~/hosts.txt
    grep -i $(hostname) /etc/hosts | sort -n | sed '1d' | xargs -I X sed -e s/X//g -i ~/hosts.txt
    sudo cp ~/hosts.txt /etc/hosts
    awk '{gsub(/[ \t]/,\"\n\")}1' ~/hosts.txt > ~/temp.txt && mv ~/temp.txt ~/hosts.txt
	
    ssh-keyscan -f ~/hosts.txt >> ~/.ssh/known_hosts
    rm ~/hosts.txt

    # copy to master
    if [[ \$MACHINENNUM != 0 ]]
    then
        sshpass -p $PASS ssh-copy-id $USRNM@$MSTR
    fi

    # copy to peers
    s=1
    while [[ \$s -le $(( NUMSLVS )) ]];
    do
        if [[ \$MACHINENNUM != \$s ]]
        then
            sshpass -p $PASS ssh-copy-id $USRNM@$SLVPREFX-\$s
        fi
        s=\$((s+1))
    done
    chmod 0600 ~/.ssh/authorized_keys
    " < /dev/null
    MACHINENNUM=$((MACHINENNUM+1))

done

echo -e "\nDone." 1>&3 2>&4
echo -e "\nHopefully it worked :-#" 1>&3 2>&4

exit 0
