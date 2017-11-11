#!/bin/sh

. /etc/sysconfig/heat-params

echo "configuring kubernetes (master)"

# Get kubernetes version
K8S_VERSION=$(rpm -q --queryformat "%{VERSION}" kubernetes-common)

# Generate ServiceAccount key if needed
SERVICE_ACCOUNT_KEY="/var/lib/kubernetes/serviceaccount.key"
if [[ ! -f "${SERVICE_ACCOUNT_KEY}" ]]; then
    mkdir -p "$(dirname ${SERVICE_ACCOUNT_KEY})"
    openssl genrsa -out "${SERVICE_ACCOUNT_KEY}" 2048 2>/dev/null
fi

# Setting correct permissions for Kubernetes files
chown -R kube:kube /var/lib/kubernetes

# note: we will not use the $SERVICE_ACCOUNT_KEY yet: it would require to use the same
#       key in all the masters, and that is annoying... k8s will use the API server key
#       when not specifying it, so not a big deal [alvaro]
# KUBE_API_ARGS="--service-account-key-file=$SERVICE_ACCOUNT_KEY --runtime_config=api/all=true"
KUBE_API_ARGS="--runtime-config=api/all=true"

if [ "$TLS_DISABLED" == "True" ]; then
    sed -i '
        /^# KUBE_API_PORT=/ s|.*|KUBE_API_PORT="--port=8080 --insecure-port='"$KUBE_API_PORT"'"|
    ' /etc/kubernetes/apiserver
else
    # insecure port is used internaly
    sed -i '
        /^# KUBE_API_PORT=/ s|.*|KUBE_API_PORT="--port=8080 --insecure-port=8080 --secure-port='"$KUBE_API_PORT"'"|
    ' /etc/kubernetes/apiserver
    KUBE_API_ARGS="$KUBE_API_ARGS --tls-cert-file=/etc/kubernetes/ssl/server.crt"
    KUBE_API_ARGS="$KUBE_API_ARGS --tls-private-key-file=/etc/kubernetes/ssl/server.key"
    KUBE_API_ARGS="$KUBE_API_ARGS --client-ca-file=/etc/kubernetes/ssl/ca.crt"
fi

sed -i '
    /^KUBE_ALLOW_PRIV=/ s|=.*|="--allow-privileged='"$KUBE_ALLOW_PRIV"'"|
' /etc/kubernetes/config

sed -i '
    /^KUBE_API_ADDRESS=/ s|=.*|="--advertise-address='"$KUBE_NODE_IP"' --insecure-bind-address=0.0.0.0 --bind-address=0.0.0.0"|
    /^KUBE_SERVICE_ADDRESSES=/ s|=.*|="--service-cluster-ip-range='"$PORTAL_NETWORK_CIDR"'"|
    /^KUBE_API_ARGS=/ s|=.*|="'"$KUBE_API_ARGS"' --cloud-config=/etc/sysconfig/kubernetes_openstack_config --cloud-provider=openstack"|
    /^KUBE_ETCD_SERVERS=/ s/=.*/="--etcd-servers=http:\/\/127.0.0.1:2379"/
    /^KUBE_ADMISSION_CONTROL=/ s/=.*/="--admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,ResourceQuota"/
' /etc/kubernetes/apiserver

sed -i '
    /^KUBE_CONTROLLER_MANAGER_ARGS=/ s|=.*|="--service-account-private-key-file='"$SERVICE_ACCOUNT_KEY"' --leader-elect=true --cluster-name=kubernetes --cluster-cidr='"$FLANNEL_NETWORK_CIDR"' --cloud-config=/etc/sysconfig/kubernetes_openstack_config --cloud-provider=openstack"|
' /etc/kubernetes/controller-manager

# Generate a the configuration for Kubernetes services to talk to OpenStack Neutron
cat > /etc/sysconfig/kubernetes_openstack_config <<EOF
[Global]
auth-url=$AUTH_URL
Username=$USERNAME
Password=$PASSWORD
tenant-name=$TENANT_NAME
domain-name=$TENANT_DOMAIN
[LoadBalancer]
lb-version=v2
subnet-id=$CLUSTER_SUBNET
create-monitor=yes
monitor-delay=1m
monitor-timeout=30s
monitor-max-retries=3
EOF

# If Kubernetes version is 1.7.x, add blockstorage version
if echo $K8S_VERSION | grep -q "^1\.7"; then
    echo "[BlockStorage]" >> /etc/sysconfig/kubernetes_openstack_config
    echo "bs-version=v2" >> /etc/sysconfig/kubernetes_openstack_config
fi

for service in kube-apiserver kube-scheduler kube-controller-manager; do
    echo "activating $service service"
    systemctl enable $service

    echo "starting $service services"
    systemctl --no-block start $service
done
