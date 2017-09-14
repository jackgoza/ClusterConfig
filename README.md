# ClusterConfig

Prerequisite: upload your public key to CloudLab.
<a href="https://cdn.rawgit.com/anask/ClusterConfig/0cf7f80a/html/cloudlab-ssh-keys-setup.html"> See tutorial.</a>

1. Create a Mitaka cluster in Utah using type m400.
2. Clone https://github.com/anask/ClusterConfig and cd ClusterConfig
3. Get the public ips of the machines in the cluster. Save them to cluster-machines.txt.
   with the master machine on the first line.

Set up one password and ssh keys for a cluster of machines:
./set-cluster-passwd.sh

Set up a Hadoop and Spark cluster on these machines:
<br/>execute ./instance-setup.sh on every machine.
<br/>&nbsp;or
<br/>execute ./run-instance-setup.sh from your local machine.

Then follow the last notes printed on the master (or in CLSTR_README.txt).

Designed for use with <a href="https://www.cloudlab.us/">CloudLab</a>.
Tested on OpenStack Mitaka.
