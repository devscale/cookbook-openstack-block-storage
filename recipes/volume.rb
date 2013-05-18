#
# Cookbook Name:: openstack-block-storage
# Recipe:: volume
#
# Copyright 2012, Rackspace US, Inc.
# Copyright 2012-2013, AT&T Services, Inc.
# Copyright 2013, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class ::Chef::Recipe
  include ::Openstack
end

if node["openstack-block-storage"]["syslog"]["use"]
  include_recipe "openstack-common::logging"
end

platform_options = node["openstack-block-storage"]["platform"]

platform_options["cinder_volume_packages"].each do |pkg|
  package pkg do
    options platform_options["package_overrides"]

    action :upgrade
  end
end

platform_options["cinder_iscsitarget_packages"].each do |pkg|
  package pkg do
    options platform_options["package_overrides"]

    action :upgrade
  end
end

db_user = node["openstack-block-storage"]["db"]["username"]
db_pass = db_password "cinder"
sql_connection = db_uri("volume", db_user, db_pass)

rabbit_server_role = node["openstack-block-storage"]["rabbit_server_chef_role"]
rabbit_info = config_by_role rabbit_server_role, "queue"

rabbit_user = node["openstack-block-storage"]["rabbit"]["username"]
rabbit_pass = user_password "rabbit"
rabbit_vhost = node["openstack-block-storage"]["rabbit"]["vhost"]

glance_api_role = node["openstack-block-storage"]["glance_api_chef_role"]
glance = config_by_role glance_api_role, "glance"
glance_api_endpoint = endpoint "image-api"

node.override["openstack-block-storage"]["netapp"]["dfm_password"] = service_password "netapp"

service "cinder-volume" do
  service_name platform_options["cinder_volume_service"]
  supports :status => true, :restart => true

  action [ :enable, :start ]
end

template "/etc/cinder/cinder.conf" do
  source "cinder.conf.erb"
  group  node["openstack-block-storage"]["group"]
  owner  node["openstack-block-storage"]["user"]
  mode   00644
  variables(
    :sql_connection => sql_connection,
    :rabbit_ipaddress => rabbit_info["host"],
    :rabbit_user => rabbit_user,
    :rabbit_password => rabbit_pass,
    :rabbit_port => rabbit_info["port"],
    :rabbit_virtual_host => rabbit_vhost,
    :glance_host => glance_api_endpoint.host,
    :glance_port => glance_api_endpoint.port
  )

  notifies :restart, "service[cinder-volume]"
end

service "iscsitarget" do
  service_name platform_options["cinder_iscsitarget_service"]
  supports :status => true, :restart => true

  action :enable
end

template "/etc/tgt/targets.conf" do
  source "targets.conf.erb"
  mode   00600

  notifies :restart, "service[iscsitarget]", :immediately
end
