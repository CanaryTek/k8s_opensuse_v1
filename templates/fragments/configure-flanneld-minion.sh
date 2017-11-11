#!/bin/sh

. /etc/sysconfig/heat-params

IFS='|'
MASTER_IPS=($KUBE_MASTER_IPS)
for i in "${!MASTER_IPS[@]}"; do
    echo "${MASTER_IPS[$i]}        kube-master${i}" >> /etc/hosts
done

MINION_IPS=($KUBE_MINION_IPS)
for i in "${!MINION_IPS[@]}"; do
    echo "${MINION_IPS[$i]}        kube-minion${i}" >> /etc/hosts
done

if [ "$NETWORK_DRIVER" != "flannel" ]; then
    exit 0
fi

sed -i '
    /^FLANNEL_ETCD_ENDPOINTS=/ s|=.*|="http://'"$ETCD_SERVER_IP"':2379"|
    /^#FLANNEL_OPTIONS=/ s//FLANNEL_OPTIONS="-iface eth0 --ip-masq"/
' /etc/sysconfig/flanneld

cat >> /etc/sysconfig/flanneld <<EOF

# etcd config key.  This is the configuration key that flannel queries
# For address range assignment
FLANNEL_ETCD_KEY="/flannel/network"
EOF

echo "activating flanneld service"
systemctl enable flanneld

echo "starting flanneld service"
systemctl --no-block start flanneld
