# ClusterConfig

Prerequisite: upload your public key to CloudLab.
<a href="https://cdn.rawgit.com/anask/ClusterConfig/0cf7f80a/html/cloudlab-ssh-keys-setup.html"> See tutorial.</a>

Set up one password and ssh keys for a cluster of machines:
./set-cluster-passwd.sh

Set up a Hadoop and Spark cluster on these machines:
Execute ./instance-setup.sh on every machine.

Then follow the last notes printed on the master.

Designed for use with <a href="https://www.cloudlab.us/">CloudLab</a>.
Tested on OpenStack Mitaka.
