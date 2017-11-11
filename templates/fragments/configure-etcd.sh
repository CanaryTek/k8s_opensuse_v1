#!/bin/sh

. /etc/sysconfig/heat-params

myip="$KUBE_NODE_IP"

sed -i '
    /ETCD_NAME=/c ETCD_NAME="'$KUBE_NODE_NAME'"
    /ETCD_DATA_DIR=/c ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
    /ETCD_LISTEN_CLIENT_URLS=/c ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
    /ETCD_LISTEN_PEER_URLS=/c ETCD_LISTEN_PEER_URLS="http://'$myip':2380"
    /ETCD_ADVERTISE_CLIENT_URLS=/c ETCD_ADVERTISE_CLIENT_URLS="http://'$myip':2379"
    /ETCD_INITIAL_ADVERTISE_PEER_URLS=/c ETCD_INITIAL_ADVERTISE_PEER_URLS="http://'$myip':2380"
' /etc/sysconfig/etcd

echo "# IP address for kube-apiserver" >> /etc/hosts
echo "$KUBE_API_PRIVATE_ADDRESS        kube-master" >> /etc/hosts
echo "# IP addresses of kubernetes master nodes" >> /etc/hosts

IFS='|'
ETCD_IPS=($KUBE_MASTER_IPS)

LOOP_NUM=`expr ${#ETCD_IPS[@]} - 1`
ETCD_INIT=""
for i in "${!ETCD_IPS[@]}"; do
    echo "${ETCD_IPS[$i]}        kube-master${i}" >> /etc/hosts
    ETCD_INIT="${ETCD_INIT}kube-master${i}=http://${ETCD_IPS[$i]}:2380"
    if [ "$i" -lt "$LOOP_NUM" ]; then
        ETCD_INIT="${ETCD_INIT},"
    fi
done

MINION_IPS=($KUBE_MINION_IPS)
for i in "${!MINION_IPS[@]}"; do
    echo "${MINION_IPS[$i]}        kube-minion${i}" >> /etc/hosts
done

if [ ${ETCD_DISCOVERY_URL} == "None" ] || [ ${ETCD_DISCOVERY_URL} == "none" ]; then

    sed -i '
        /ETCD_INITIAL_CLUSTER=/c ETCD_INITIAL_CLUSTER="'$ETCD_INIT'"
        /ETCD_INITIAL_CLUSTER_STATE=/c ETCD_INITIAL_CLUSTER_STATE=new
' /etc/sysconfig/etcd

else

    sed -i '
        /ETCD_DISCOVERY=/c ETCD_DISCOVERY="'$ETCD_DISCOVERY_URL'"
' /etc/sysconfig/etcd

fi

echo "activating etcd service"
systemctl enable etcd

echo "starting etcd service"
systemctl --no-block start etcd
