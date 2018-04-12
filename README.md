# Magnum openSUSE Kubernetes driver

This is an updated openSUSE Kubernetes driver for SUSE Cloud 7 Magnum

It enhances the original SUSE driver with the following changes

- Correctly configure Kubernetes to "talk" to OpenStack, so it can create OS LoadBalancers for Kubernetes services and use cinder volumes
- It works with SUSE's provided image openstack-magnum-k8s-image that includes kubernetes 1.3.10 (quite outdated)
- It also works with author's provided openSUSE image that includes Kubernetes 1.8.5 (read below)

## Installation

  * In magnum controller, substitute the provider k8s_opensuse_v1 with this driver in ```/usr/lib/python2.7/site-packages/magnum/drivers/k8s_opensuse_v1```
  * Restart magnum services (magnum-api and magnum-conductor)

## Usage with SUSE Cloud7 provided image (Kubernetes version 1.3.10)

  * Install the openstack-magnum-k8s-image package

```
zypper in openstack-magnum-k8s-image
```

  * Create the image

```
openstack image create openstack-magnum-k8s-image \
--public --disk-format qcow2 \
--property os_distro='opensuse' \
--container-format bare \
--file /srv/tftpboot/files/openstack-magnum-k8s-image/openstack-magnum-k8s-image.x86_64.qcow2
```

  * Create the flavor (adjust to your needs)

```
openstack flavor create --public m1.magnum --id 9 --ram 1024 --disk 10 --vcpus 1
```

  * Create cluster template
    * Change USER and PASS to a valid OpenStack user/pass
    * You may also want to change the docker-volume-size. It's the size used to store docker containers

```
magnum cluster-template-create --name k8s_template_suse \
--image-id openstack-magnum-k8s-image \
--keypair-id default \
--external-network-id floating \
--dns-nameserver 8.8.8.8 \
--flavor-id m1.magnum \
--master-flavor-id m1.magnum \
--docker-volume-size 5 \
--network-driver flannel \
--coe kubernetes \
--volume-driver cinder \
--master-lb-enabled \
--labels "username=USER,password=PASS"
```

  * Create cluster

```
magnum cluster-create --name k8s_cluster --cluster-template k8s_template_suse \
--master-count 1 --node-count 3
```

## Usage with author's provided image (Kubernetes version 1.8)

This setup uses a custom image created with openSUSE Leap 42.3 with Kubernetes 1.8

This image is created using openSUSE's kiwi and OBS and is hosted at https://build.opensuse.org/package/show/home:kuko:images/openSUSE-Leap-42.3-Magnum-Kubernetes-1.7

Yes, the repo has a 1.7 in it's name, but now it's really Kubernetes 1.8. I will create a new project with no version in it's name...

  * Download the Kubernetes 1.8 image

```
wget "https://download.opensuse.org/repositories/home:/kuko:/images/images/openSUSE-Leap-42.3-Magnum-Kubernetes-1.7.x86_64-1.42.3-mit-Build3.29.qcow2"
```

  * Create the image

```
openstack image create leap-k8s-magnum \
--public --disk-format qcow2 \
--property os_distro='opensuse' \
--container-format bare \
--file openSUSE-Leap-42.3-Magnum-Kubernetes-1.7.x86_64-1.42.3-mit-Build3.29.qcow2
```

  * Create the flavor (adjust to your needs)

```
openstack flavor create --public m1.magnum --id 9 --ram 1024 --disk 10 --vcpus 1
```

  * Create cluster template
    * Change USER and PASS to a valid OpenStack user/pass
    * You may also want to change the docker-volume-size. It's the size used to store docker containers

```
magnum cluster-template-create --name k8s_template_suse_k8s_1.8 \
--image-id leap-k8s-magnum \
--keypair-id default \
--external-network-id floating \
--dns-nameserver 8.8.8.8 \
--flavor-id m1.magnum \
--master-flavor-id m1.magnum \
--docker-volume-size 5 \
--network-driver flannel \
--coe kubernetes \
--volume-driver cinder \
--master-lb-enabled \
--labels "username=USER,password=PASS"
```

  * Create cluster

```
magnum cluster-create --name k8s_cluster --cluster-template k8s_template_suse_k8s_1.8 \
--master-count 1 --node-count 3
```

