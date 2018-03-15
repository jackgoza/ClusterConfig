#!/bin/bash
#==============================================================================
#
#          FILE:  instance-setup.sh
#
#         USAGE:  ./instance-setup.sh -p <password> [-c num_slaves]
#
#   DESCRIPTION:
#                 This script is intended to setup the machine for first time
#                 use only. It will perform updates and install normally used
#                 packages.
#
#                 The script can be customized to install additional packages.
#                 To install additonal packages modifiy the custom section.
#
#                 The current custom section installs scala, hadoop, and spark. It assumes
#                 that the master can perform an ssh key based login on all the workers.
#                 It is intended and tested for use in a CloudLab OpenStack cluster.
#
#
#                 It is recommended that "sudo apt-get upgrade" is run manually
#                 because some packages require configuration.
#
#                 Default Installation:
#                   * java (jre,jdk)
#                   * vim
#
#
#   WARNING:
#                When using -c num_slaves:
#
#                0. Make sure the /etc/hostname file has a defined hostname on all
#                   machines. Sometimes, CloudLab will not not configure that file
#                   automatically.
#                   hostname example: master.test1.project.utah.cloudlab.us
#
#                1. Change SLVPREFX=cp MSTR=ctl according to your cluster.
#                   For example: SLVPREFX=slave ; MSTR=master
#
#                2. A symbolic link is created to store hdfs data in a place other
#                   than /usr/local/, that is /dev/data
#                   This is due the space limitation in the /usr/local/ directory.
#
#                   However, if the machine is rebooted all user generated files in
#                   /dev/data could be lost.
#
#                   You can change this default location by setting LRGDIR.
#
#       OPTIONS:  -p   set user password
#                 -c   run the script's customized installation section
#
#  REQUIREMENTS:  ---
#          BUGS:  ---
#         NOTES:
#                 Tested software versions:
#                   scala-2.11.8
#                   hadoop-2.7.3
#                   spark-2.0.2 for hadoop2.7
#
#                 Assuming the default java version will be compatible.
#                 To replace default java uncomment lines below 'INSTALL JAVA 8'
#
#
#        AUTHOR:  Anas Katib, anaskatib@mail.umkc.edu
#   INSTITUTION:  University of Missouri-Kansas City
#       VERSION:  1.0
#       CREATED:  06/14/2016 03:00:00 PM CST
#      REVISION:  09/13/2017 06:55:00 PM CST
#
#==============================================================================
# Refs:
# http://www.michael-noll.com/tutorials/running-hadoop-on-ubuntu-linux-single-node-cluster/
# http://blog.insightdatalabs.com/spark-cluster-step-by-step/
# https://www.tutorialspoint.com/hadoop/hadoop_mapreduce.htm
# https://www.tutorialspoint.com/hadoop/hadoop_multi_node_cluster.htm
# http://chaalpritam.blogspot.com/2015/05/hadoop-270-single-node-cluster-setup-on.html
# http://chaalpritam.blogspot.com/2015/05/hadoop-270-multi-node-cluster-setup-on.html
# http://hadoop.apache.org/docs/r2.7.3/hadoop-project-dist/hadoop-common/ClusterSetup.html
# http://hadoop.apache.org/docs/r2.7.3/hadoop-project-dist/hadoop-common/SingleCluster.html
#
#
# sudo groupadd $USRGRP
# sudo useradd -m -d /home/$USER/ -s /bin/bash -G $USRGRP,sudo $USER
# echo -e $PASSWORD"\n"$PASSWORD | sudo passwd $USER
# su $USER
#==============================================================================

scriptname=$0
NSLVS=$4
USRGRP=$(groups | cut -d ' ' -f1)
SLVPREFX='cp'
MSTR='ctl'
LRGDIR=/dev/data
NUMREP=1
SCALA_VER=2.11.8
HADOOP_VER=2.7.5
SPARK_VER=2.0.2
SPARK_HDP_VER=$(echo $HADOOP_VER | cut -d '.' -f1-2)

function usage {
    echo "USAGE: $scriptname -p <password> [-c num_slaves]"
    echo "  -p <password>       password for the current user"
    echo "  -c num_slaves       run the customized section"
    echo "  -h                  print this message"
    echo -e "\nWARN:"
    echo "- Using $LRGDIR to store data. Directory could be volatile."
    echo "  Change it if machine reboot is anticipated."
    echo -e "\nINFO:"
    echo "- Replication Factor: "$NUMREP
    echo "- Software Versions: "
    echo "              Scala: "$SCALA_VER
    echo "             Hadoop: "$HADOOP_VER
    echo "              Spark: "$SPARK_VER
    echo "- Please read the notes in the script file!"
    exit 1
}

function aparse {
while [[ $# > 0 ]] ; do
  case "$1" in
    -p)
      PASSWORD=${2}
      shift
      ;;
    -c)
      CUSTOM=true
      ;
  esac
  shift
done
}

if [[ ($# -eq 0) || ( "$1" == "-h")  ]] ; then
    usage
    exit 1
fi

sudo echo -n "CHECKING SUDO PRIVILEGES.."
if [[  "$USER" == "root" ]]; then
    echo -e "\nError: Do not run script via sudo, but you must have sudo privileges."
    exit 1
fi
echo "OK"

echo "RUNNING "$0 $@
aparse "$@"
set -e

echo -e "\nSET UP STARTED.."

if [ ! -f  /etc/hostname ]; then
   echo "ERROR:"
   echo "  The file \"/etc/hostname\" was not found!"
   echo "  Possible machine boot error. Reload the machine then assign"
   echo "  a hostname in /etc/hostname."
   echo "  Example: echo \"ctl.test1.project.utah.cloudlab.us\" > /etc/hostname"
   exit 1
fi

HSTNAME=$(cat /etc/hostname)
HSTNAME_LEN=${#HSTNAME}

if [ "$HSTNAME_LEN" -eq "0" ]; then
   echo "ERROR:"
   echo "  No hostname defined in \"/etc/hostname\". Set a hostname.";
   echo "  Example: echo \"cp-2.test1.project.utah.cloudlab.us\" > /etc/hostname"
   exit 1;
fi

echo "UPDATING REPOSITORIES AND PACKAGES.."
sudo apt-get update  --yes      # Fetches the list of available updates
#sudo apt-get upgrade --yes     # Strictly upgrades the current packages
#sudo apt-get dist-upgrade      # Installs updates (new ones)

echo "INSTALLING OTHERS.."
sudo apt-get install default-jre --yes
sudo apt-get install default-jdk --yes
sudo apt-get install vim --yes

sudo apt-get -f install
sudo apt-get install unzip --yes
sudo apt-get install software-properties-common --yes
sudo apt-get install maven --yes
sudo apt-get install jq --yes

# sudo apt-get update --yes

# INSTALL JAVA 8
#   to replace java-default
#   sudo apt-get install openjdk-8-jdk --yes
#   sudo apt-get install openjdk-8-jre --yes
#   sudo apt-get autoremove --yes
#   sudo update-alternatives --config java
#   sudo update-alternatives --config javac


if [[ ($CUSTOM) ]] ; then

    echo "CUSTOM CONFIGURATION STARTED.."

    # SET UP VIM CONFIGURATION
    echo "SETTING UP VIM.."
    sudo touch ~/.vimrc
    sudo chown -R $USER:$USRGRP  ~/.vimrc
    echo 'set hlsearch' >> ~/.vimrc
    echo 'set nonumber' >> ~/.vimrc
    echo 'set shiftwidth=4' >> ~/.vimrc
    #echo 'set expandtab' >> ~/.vimrc
    echo 'set tabstop=4' >> ~/.vimrc
    echo 'set ignorecase' >> ~/.vimrc
    echo 'set backspace=2' >> ~/.vimrc
    echo 'set nocompatible' >> ~/.vimrc
    echo 'syntax on' >> ~/.vimrc
    echo 'set colorcolumn=80' >> ~/.vimrc
    echo 'highlight ColorColumn ctermbg=gray' >> ~/.vimrc

    echo "INSTALLING SCALA.."
    #INSTALL SCALA
    sudo apt-get remove scala-library scala --yes
    wget http://www.scala-lang.org/files/archive/scala-$SCALA_VER.deb
    sudo dpkg -i scala-$SCALA_VER.deb
    sudo apt-get update --yes
    sudo apt-get install scala --yes

    echo "DOWNLOADING HADOOP.."
    # how many servers to try:
    NUM_HSEV=$(curl -s 'http://www.apache.org/dyn/closer.cgi?as_json=1' | jq --raw-output '.http[]' | wc -l)
    HSERV=0
    ISZIP=""

    while [ ${#ISZIP} -eq 0 ] && [ $HSERV -lt $NUM_HSEV ]
    do
        HADOOP_URL=$(curl -s 'http://www.apache.org/dyn/closer.cgi?as_json=1' | jq --raw-output ".http[$HSERV]")"hadoop/common/hadoop-$HADOOP_VER/hadoop-$HADOOP_VER.tar.gz"
        echo "  TRYING: "$HADOOP_URL
        wget $HADOOP_URL &> /dev/null
        HDFT=$(file hadoop-$HADOOP_VER*)
        ISZIP=$(echo $HDFT | grep 'gzip compressed data')
        HSERV=$((HSERV+1))
    done

    HDFT=$(file hadoop-$HADOOP_VER*)
    IS_HZIP=$(echo $HDFT | grep 'gzip compressed data')
    if [ ${#IS_HZIP} -eq 0 ]; then
        echo 'ERROR: COULD NOT DOWNLOAD HADOOP '$HADOOP_VER
        exit 1
    fi

    echo "DOWNLOADING SPARK.."
    # how many servers to try:
    NUM_SSEV=$(curl -s 'http://www.apache.org/dyn/closer.cgi?as_json=1' | jq --raw-output '.http[]' | wc -l)
    SSERV=0
    ISZIP=""

    while [ ${#ISZIP} -eq 0 ] && [ $SSERV -lt $NUM_SSEV ]
    do
        SPARK_URL=$(curl -s 'http://www.apache.org/dyn/closer.cgi?as_json=1' | jq --raw-output ".http[$SSERV]")"spark/spark-$SPARK_VER/spark-$SPARK_VER-bin-hadoop$SPARK_HDP_VER.tgz"
        echo "  TRYING: "$SPARK_URL
        wget $SPARK_URL &> /dev/null
        SFT=$(file spark-$SPARK_VER*)
        ISZIP=$(echo $SFT | grep 'gzip compressed data')
        SSERV=$((SSERV+1))
    done

    SFT=$(file spark-$SPARK_VER*)
    IS_SZIP=$(echo $SFT | grep 'gzip compressed data')
    if [ ${#IS_SZIP} -eq 0 ]; then
        echo 'ERROR: COULD NOT DOWNLOAD SPARK '$SPARK_VER
        exit 1
    fi

    sudo tar xzf hadoop-$HADOOP_VER*gz -C /usr/local
    sudo tar xzf spark-$SPARK_VER*gz -C /usr/local

    cd /usr/local
    sudo mv hadoop-$HADOOP_VER* hadoop
    sudo mv spark-$SPARK_VER* spark
    sudo mkdir -p $LRGDIR/hadoop

    sudo chown -R $USER:$USRGRP  /usr/local/hadoop
    sudo chown -R $USER:$USRGRP  /usr/local/spark
    sudo chown -R $USER:$USRGRP  $LRGDIR

    ln -s $LRGDIR/hadoop /usr/local/hadoop/hadoop_data
    mkdir -p /usr/local/hadoop/hadoop_data/hdfs/tmp

    if [[  $HSTNAME == *"$MSTR"* ]]; then
        echo "SETTING UP MASTER.."
        #sudo apt-get install libfreetype6-dev libpng-dev --yes
        #pip install matplotlib

        MSTRNAME=$HSTNAME
        touch /usr/local/spark/conf/slaves
        #echo "
        #spark.master                spark://$MSTRNAME:7077
        #spark.driver.memory         50g
        #spark.executor.memory       50g
        #spark.executor.cores        1
        #spark.submit.deployMode     cluster
        # spark.eventLog.dir         hdfs://$MSTR:8021/sparkEvntLg
        #" > /usr/local/spark/conf/spark-defaults.conf

        mkdir /usr/local/hadoop/hadoop_data/hdfs/namenode
        echo $MSTRNAME >  /usr/local/hadoop/etc/hadoop/masters
        echo -n > /usr/local/hadoop/etc/hadoop/slaves
    	snum=1
    	while [[ $snum -le $NSLVS ]];
    	do
	        echo $SLVPREFX-$snum >> /usr/local/hadoop/etc/hadoop/slaves
	        echo $SLVPREFX-$snum >>	/usr/local/spark/conf/slaves
	        snum=$((snum+1))
    	done
    	# hdfs-site.xml
    	echo '<?xml version="1.0" encoding="UTF-8"?>
        <?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
        <configuration>
            <property>
              <name>dfs.replication</name>
              <value>'$NUMREP'</value>
            </property>
            <property>
              <name>dfs.namenode.name.dir</name>
              <value>file:/usr/local/hadoop/hadoop_data/hdfs/namenode</value>
            </property>
            <property>
              <name>dfs.permissions</name>
              <value>false</value>
            </property>
        </configuration>
    	' > /usr/local/hadoop/etc/hadoop/hdfs-site.xml
    	
	git clone https://github.com/intel-hadoop/HiBench.git ~/HiBench
    else
        echo "SETTING UP SLAVE.."
        mkdir /usr/local/hadoop/hadoop_data/hdfs/datanode
    	echo '<?xml version="1.0" encoding="UTF-8"?>
        <?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
        <configuration>
            <property>
              <name>dfs.replication</name>
              <value>'$NUMREP'</value>
            </property>
            <property>
                  <name>dfs.datanode.data.dir</name>
                  <value>file:/usr/local/hadoop/hadoop_data/hdfs/datanode</value>
            </property>
            <property>
              <name>dfs.permissions</name>
              <value>false</value>
            </property>
        </configuration>
    	' > /usr/local/hadoop/etc/hadoop/hdfs-site.xml

    fi

    # core-site.xml
    echo '<?xml version="1.0" encoding="UTF-8"?>
    <?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
    <configuration>
        <property>
            <name>fs.defaultFS</name>
            <value>hdfs://'$MSTR':9000</value>
        </property>
        <property>
            <name>hadoop.tmp.dir</name>
            <value>file:/usr/local/hadoop/hadoop_data/tmp</value>
        </property>
    </configuration>
    ' > /usr/local/hadoop/etc/hadoop/core-site.xml


    # mapred-site.xml
    echo '<?xml version="1.0"?>
    <?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
    <configuration>
        <property>
          <name>mapreduce.framework.name</name>
          <value>yarn</value>
        </property>
    </configuration>
    ' > /usr/local/hadoop/etc/hadoop/mapred-site.xml

    # yarn-site.xml
    echo '<?xml version="1.0"?>
    <configuration>
            <property>
                <name>yarn.nodemanager.aux-services</name>
                <value>mapreduce_shuffle</value>
            </property>
            <property>
                <name>yarn.nodemanager.aux-services.mapreduce.shuffle.class</name>
                <value>org.apache.hadoop.mapred.ShuffleHandler</value>
            </property>
            <property>
                     <name>yarn.resourcemanager.resource-tracker.address</name>
                     <value>'$MSTR':8025</value>
            </property>
            <property>
                     <name>yarn.resourcemanager.scheduler.address</name>
                     <value>'$MSTR':8030</value>
            </property>
            <property>
                     <name>yarn.resourcemanager.address</name>
                     <value>'$MSTR':8050</value>
            </property>
    </configuration>
    ' > /usr/local/hadoop/etc/hadoop/yarn-site.xml

    echo "# Hadoop Variables"  >> $HOME/.bashrc
    echo "export JAVA_HOME=/usr/lib/jvm/default-java"  >> $HOME/.bashrc
    echo "export HADOOP_HOME=/usr/local/hadoop"  >> $HOME/.bashrc
    echo "export PATH=\$PATH:\$HADOOP_HOME/bin"  >> $HOME/.bashrc
    echo "export PATH=\$PATH:\$HADOOP_HOME/sbin" >> $HOME/.bashrc
    echo "export HADOOP_MAPRED_HOME=\$HADOOP_HOME"  >> $HOME/.bashrc
    echo "export HADOOP_COMMON_HOME=\$HADOOP_HOME"  >> $HOME/.bashrc
    echo "export HADOOP_HDFS_HOME=\$HADOOP_HOME"  >> $HOME/.bashrc
    echo "export YARN_HOME=\$HADOOP_HOME"  >> $HOME/.bashrc
    echo "export HADOOP_COMMON_LIB_NATIVE_DIR=\$HADOOP_HOME/lib/native"  >> $HOME/.bashrc
    echo 'export HADOOP_OPTS="-Djava.library.path=$HADOOP_HOME/lib"'  >> $HOME/.bashrc
    echo 'export JAVA_HOME="/usr/lib/jvm/default-java"'  >> hadoop/etc/hadoop/hadoop-env.sh


    echo "# Spark Variables" >> $HOME/.bashrc
    echo "export SPARK_HOME=/usr/local/spark" >> $HOME/.bashrc
    echo "export PATH=\$PATH:\$SPARK_HOME/bin" >> $HOME/.bashrc

    cp spark/conf/spark-env.sh.template spark/conf/spark-env.sh

    echo 'export JAVA_HOME=/usr' >> spark/conf/spark-env.sh
    echo "export SPARK_PUBLIC_DNS=$HSTNAME" >> spark/conf/spark-env.sh
    #echo 'export SPARK_WORKER_CORES=1' >> spark/conf/spark-env.sh

    if [[  $HSTNAME == *"$MSTR"* ]]; then
        ADD_LINE=$(grep -i $(hostname) /etc/hosts)
        ADDRS=($ADD_LINE)
        PUB_ADD=${ADDRS[-1]}
        # Generate README file
        README="CLSTR_README.txt"
        touch $HOME/$README
        echo -e "\nINFO: AFTER ALL NODES ARE READY, EXECUTE THE COMMANDS BELOW ON THE MASTER ONLY." >> $HOME/$README
		echo "  source $HOME/.bashrc"  >> $HOME/$README
		echo '  hdfs namenode -format' >> $HOME/$README
        echo '  start-dfs.sh' >> $HOME/$README
        echo '  start-yarn.sh' >> $HOME/$README
        echo '  $SPARK_HOME/sbin/start-all.sh' >> $HOME/$README
        echo -e "\nINFO: WEB UI PORTS:" >> $HOME/$README
        echo    "  Hadoop $PUB_ADD:50070" >> $HOME/$README
        echo    "  Yarn   $PUB_ADD:8088" >> $HOME/$README
        echo    "  Spark  $PUB_ADD:8080 (or 8081, 8082..)" >> $HOME/$README
        echo -e "\nEXECUTE 'jps' TO CHECK WHICH JVM PROCESSES ARE RUNNING.\n" >> $HOME/$README
        cat  $HOME/$README
        echo "TO PRINT THIS MESSAGE AGAIN, EXECUTE: cat $HOME/$README"
    fi

fi

echo "SETUP FINISHED."
