#!/bin/bash
# Install MariaDB Galera Cluster
#
# $1 - number of nodes; $2 - cluster name;
#
NNODES=${1-1}
PASSWORD=${2:-`date +%D%A%B | md5sum| sha256sum | base64| fold -w16| head -n1`}
IPLIST=`echo ""`
MYIP=`ip route get 10.0.0.5 | awk 'NR==1 {print $NF}'`
MYNAME=`echo "Node$MYIP" | sed 's/10.0.0.1/-/'`
CNAME=${3:-"GaleraCluster"}

for (( n=1; n<=$NNODES; n++ ))
do
   IPLIST+=`echo "10.0.0.$(( $n + 9 ))"`
   if [ "$n" -lt $NNODES ];
   then
        IPLIST+=`echo ","`
   fi
done

cd ~
#apt-get update
#apt-get -fy dist-upgrade
#apt-get -fy upgrade
apt-get install lsb-release bc
REL=`lsb_release -sc`
DISTRO=`lsb_release -is | tr [:upper:] [:lower:]`
# NCORES=` cat /proc/cpuinfo | grep cores | wc -l`
# WORKER=`bc -l <<< "4*$NCORES"`

apt-get install -y --fix-missing python-software-properties
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
add-apt-repository "deb [arch=amd64] http://mirror.edatel.net.co/mariadb/repo/5.5/$DISTRO $REL main"

apt-get update

DEBIAN_FRONTEND=noninteractive apt-get install -y rsync mariadb-galera-server

service mysql stop

# create Galera config file

wget https://raw.githubusercontent.com/juliosene/azure-mariadb-galera/master/cluster.cnf

sed -i "s/IPLIST/$IPLIST/g;s/MYIP/$MYIP/g;s/MYNAME/$MYNAME/g;s/CLUSTERNAME/$CNAME/g" cluster.cnf
mv cluster.cnf /etc/mysql/conf.d/

# Create Debian manager config file

wget https://raw.githubusercontent.com/juliosene/azure-mariadb-galera/master/debian.cnf

sed -i "s/IPLIST/$IPLIST/g;s/MYIP/$MYIP/g;s/MYNAME/$MYNAME/g;s/#PASSWORD#/$PASSWORD/g" debian.cnf
mv debian.cnf /etc/mysql/

# Starts a cluster if is the first node

if [ "10.0.0.10" = "$MYIP" ];
then
   service mysql start --wsrep-new-cluster
else
   service mysql start
fi

# To check cluster use the command below
# mysql -u root -e 'SELECT VARIABLE_VALUE as "cluster size" FROM INFORMATION_SCHEMA.GLOBAL_STATUS WHERE VARIABLE_NAME="wsrep_cluster_size"'

