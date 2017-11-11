#!/bin/sh

. /etc/sysconfig/heat-params

echo "configuring kubernetes (minion)"

myip="$KUBE_NODE_IP"

ETCD_SERVER_IP=${ETCD_SERVER_IP:-$KUBE_MASTER_IP}

if [ "$TLS_DISABLED" == "True" ]; then
    KUBE_PROTOCOL="http"
    KUBE_CONFIG=""
else
    KUBE_PROTOCOL="https"
    KUBE_CONFIG="--kubeconfig=/etc/kubernetes/kubeconfig.yaml"
fi

KUBE_MASTER_URI="$KUBE_PROTOCOL://$KUBE_MASTER_IP:$KUBE_API_PORT"

sed -i '
    /^KUBE_ALLOW_PRIV=/ s/=.*/="--allow-privileged='"$KUBE_ALLOW_PRIV"'"/
    /^KUBE_ETCD_SERVERS=/ s|=.*|="--etcd-servers=http://'"$ETCD_SERVER_IP"':2379"|
    /^KUBE_MASTER=/ s|=.*|="--master='"$KUBE_MASTER_URI"'"|
' /etc/kubernetes/config

# NOTE! No KUBELET_API_SERVER in default file for kubernetes 1.7
sed -i '
    /^KUBELET_ADDRESS=/ s/=.*/="--address=0.0.0.0"/
    /^KUBELET_HOSTNAME=/ s/=.*/=""/
    /^KUBELET_API_SERVER=/ s|=.*|="--api-servers='"$KUBE_MASTER_URI"'"|
    /^KUBELET_ARGS=/ s|=.*|="--node-ip='"$myip"' --api-servers='"$KUBE_MASTER_URI"' --container-runtime=docker '"$KUBE_CONFIG"' --cloud-config=/etc/sysconfig/kubernetes_openstack_config --cloud-provider=openstack"|
' /etc/kubernetes/kubelet

sed -i '
    /^KUBE_PROXY_ARGS=/ s|=.*|="--proxy-mode=iptables '"$KUBE_CONFIG"'"|
' /etc/kubernetes/proxy

cat >> /etc/environment <<EOF
KUBERNETES_MASTER=$KUBE_MASTER_URI
EOF

# Generate a the configuration for Kubernetes services to talk to OpenStack
cat > /etc/sysconfig/kubernetes_openstack_config <<EOF
[Global]
auth-url=$AUTH_URL
Username=$USERNAME
Password=$PASSWORD
tenant-name=$TENANT_NAME
domain-name=$TENANT_DOMAIN
EOF

for service in kubelet kube-proxy; do
    echo "activating $service service"
    systemctl enable $service

    echo "starting $service service"
    systemctl --no-block start $service
done
