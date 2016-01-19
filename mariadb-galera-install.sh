#!/bin/bash
# Install MariaDB Galera Cluster
#
# $1 - number of nodes; $2 - cluster name;
#
NNODES=${1-1}
MYSQLPASSWORD=${2:-""}
DEBPASSWORD=${3:-`date +%D%A%B | md5sum| sha256sum | base64| fold -w16| head -n1`}
IPLIST=`echo ""`
MYIP=`ip route get 10.0.0.5 | awk 'NR==1 {print $NF}'`
MYNAME=`echo "Node$MYIP" | sed 's/10.0.0.1/-/'`
CNAME=${4:-"GaleraCluster"}
FIRSTNODE=`echo "10.0.0.$(( $NNODES + 9 ))"`

for (( n=1; n<=$NNODES; n++ ))
do
   IPLIST+=`echo "10.0.0.$(( $n + 9 ))"`
   if [ "$n" -lt $NNODES ];
   then
        IPLIST+=`echo ","`
   fi
done

cd ~
apt-get update
#apt-get -fy dist-upgrade
apt-get -fy upgrade
apt-get install lsb-release bc
REL=`lsb_release -sc`
DISTRO=`lsb_release -is | tr [:upper:] [:lower:]`
# NCORES=` cat /proc/cpuinfo | grep cores | wc -l`
# WORKER=`bc -l <<< "4*$NCORES"`

apt-get install -y --fix-missing python-software-properties
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
add-apt-repository "deb http://mirror.edatel.net.co/mariadb/repo/10.1/$DISTRO $REL main"

apt-get update

DEBIAN_FRONTEND=noninteractive apt-get install -y rsync mariadb-server

# Remplace Debian maintenance config file

wget https://raw.githubusercontent.com/juliosene/azure-mariadb-galera/master/debian.cnf

sed -i "s/#PASSWORD#/$DEBPASSWORD/g" debian.cnf
mv debian.cnf /etc/mysql/

mysql -u root <<EOF
GRANT ALL PRIVILEGES on *.* TO 'debian-sys-maint'@'localhost' IDENTIFIED BY '$DEBPASSWORD' WITH GRANT OPTION;
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$MYSQLPASSWORD');
FLUSH PRIVILEGES;
EOF

service mysql stop

# adjust my.cnf
# sed -i "s/#wsrep_on=ON/wsrep_on=ON/g" /etc/mysql/my.cnf

# create Galera config file

wget https://raw.githubusercontent.com/juliosene/azure-mariadb-galera/master/cluster.cnf

sed -i "s/#wsrep_on=ON/wsrep_on=ON/g;s/IPLIST/$IPLIST/g;s/MYIP/$MYIP/g;s/MYNAME/$MYNAME/g;s/CLUSTERNAME/$CNAME/g" cluster.cnf
mv cluster.cnf /etc/mysql/conf.d/

# Starts a cluster if is the first node

if [ "$FIRSTNODE" = "$MYIP" ];
then
    service mysql start --wsrep-new-cluster
else
    service mysql start --wsrep_cluster_address=gcomm://$FIRSTNODE
fi

# To check cluster use the command below
# mysql -u root -p
# mysql> SELECT VARIABLE_VALUE as "cluster size" FROM INFORMATION_SCHEMA.GLOBAL_STATUS WHERE VARIABLE_NAME="wsrep_cluster_size";
# mysql> EXIT;
#
# To add a new cluster node:
# 1 - stop MariaDB
# service mysql stop
# 2 - start as a new node
# service mysql start --wsrep_cluster_address=gcomm://10.0.0.10
