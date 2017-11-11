# Copyright 2016 Rackspace Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

import os

from magnum.drivers.common import k8s_template_def
from magnum.drivers.common import template_def
from oslo_config import cfg

CONF = cfg.CONF


class JeOSK8sTemplateDefinition(k8s_template_def.K8sTemplateDefinition):
    """Kubernetes template for openSUSE/SLES JeOS VM."""

    provides = [
        {'server_type': 'vm',
         'os': 'opensuse',
         'coe': 'kubernetes'},
    ]

    def __init__(self):
        super(JeOSK8sTemplateDefinition, self).__init__()
        self.add_parameter('docker_volume_size',
                        cluster_template_attr='docker_volume_size')
        self.add_output('kube_minions',
                        cluster_attr='node_addresses')
        self.add_output('kube_masters',
                        cluster_attr='master_addresses')

    def get_params(self, context, cluster_template, cluster, **kwargs):
        extra_params = kwargs.pop('extra_params', {})
        scale_mgr = kwargs.pop('scale_manager', None)
        if scale_mgr:
            hosts = self.get_output('kube_minions_private')
            extra_params['minions_to_remove'] = (
                scale_mgr.get_removal_nodes(hosts))

        extra_params['discovery_url'] = self.get_discovery_url(cluster)
        osc = self.get_osc(context)
        extra_params['magnum_url'] = osc.magnum_url()

        if cluster_template.tls_disabled:
            extra_params['loadbalancing_protocol'] = 'HTTP'
            extra_params['kubernetes_port'] = 8080

        label_list = ['flannel_network_cidr', 'flannel_backend',
                      'flannel_network_subnetlen', 'registry_url']
        for label in label_list:
            extra_params[label] = cluster_template.labels.get(label)

        if cluster_template.registry_enabled:
            extra_params['swift_region'] = CONF.docker_registry.swift_region
            extra_params['registry_container'] = (
                CONF.docker_registry.swift_registry_container)

        return super(JeOSK8sTemplateDefinition,
                     self).get_params(context, cluster_template, cluster,
                                      extra_params=extra_params,
                                      **kwargs)

    def get_env_files(self, cluster_template):
        env_files = []
        if cluster_template.master_lb_enabled:
            env_files.append(
                template_def.COMMON_ENV_PATH + 'with_master_lb.yaml')
        else:
            env_files.append(
                template_def.COMMON_ENV_PATH + 'no_master_lb.yaml')
        if cluster_template.floating_ip_enabled:
            env_files.append(
                template_def.COMMON_ENV_PATH + 'enable_floating_ip.yaml')
        else:
            env_files.append(
                template_def.COMMON_ENV_PATH + 'disable_floating_ip.yaml')

        return env_files

    @property
    def driver_module_path(self):
        return __name__[:__name__.rindex('.')]

    @property
    def template_path(self):
        return os.path.join(os.path.dirname(os.path.realpath(__file__)),
                            'templates/kubecluster.yaml')
