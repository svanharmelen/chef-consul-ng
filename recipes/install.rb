#
# Cookbook Name:: consul-ng
# Recipe:: install
#
# Copyright 2015, Virender Khatri
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

node['consul']['packages'].each do |p|
  package p
end

include_recipe 'consul-ng::user'

[node['consul']['parent_dir'],
 node['consul']['version_dir'],
 node['consul']['conf_dir'],
 node['consul']['pid_dir'],
 node['consul']['config']['data_dir'],
 node['consul']['log_dir']
].each do |dir|
  directory dir do
    owner node['consul']['user']
    group node['consul']['group']
    mode node['consul']['mode']
    recursive true
  end
end

if node['consul']['package_url'] == 'auto'
  package_url = "https://releases.hashicorp.com/consul/#{node['consul']['version']}/consul_#{node['consul']['version']}_linux_#{package_arch}.zip"
else
  package_url = node['consul']['package_url']
end

package_file = ::File.join(node['consul']['version_dir'], ::File.basename(package_url))
package_checksum = consul_sha256sum(node['consul']['version'])

if node['consul']['webui_package_url'] == 'auto'
  webui_package_url = "https://releases.hashicorp.com/consul/#{node['consul']['version']}/consul_#{node['consul']['version']}_web_ui.zip"
else
  webui_package_url = node['consul']['webui_package_url']
end

webui_package_file = ::File.join(node['consul']['version_dir'], ::File.basename(webui_package_url))
webui_package_checksum = webui_sha256sum(node['consul']['version'])

remote_file 'consul_package_file' do
  path package_file
  source package_url
  checksum package_checksum
end

remote_file 'webui_package_file' do
  path webui_package_file
  source webui_package_url
  checksum webui_package_checksum
end

execute 'extract_consul_package_file' do
  user node['consul']['user']
  group node['consul']['group']
  umask node['consul']['umask']
  cwd node['consul']['version_dir']
  command "unzip #{package_file}"
  creates ::File.join(node['consul']['version_dir'], 'consul')
end

execute 'extract_webui_package_file' do
  user node['consul']['user']
  group node['consul']['group']
  umask node['consul']['umask']
  cwd node['consul']['version_dir']
  command "unzip #{webui_package_file}"
  creates ::File.join(node['consul']['version_dir'], 'dist', 'index.html')
end

link node['consul']['install_dir'] do
  to node['consul']['version_dir']
end

# purge older versions
ruby_block 'purge_old_versions' do
  block do
    require 'fileutils'
    installed_versions = Dir.entries(node['consul']['parent_dir']).reject { |a| a =~ /^\.{1,2}$|^consul$/ }.sort
    old_versions = installed_versions - [node['consul']['version']]

    old_versions.each do |v|
      v = ::File.join(node['consul']['parent_dir'], v)
      FileUtils.rm_rf Dir.glob(v)
      puts "\ndeleted consul older version '#{v}'"
      Chef::Log.warn("deleted consul older version #{v}")
    end
  end
  only_if { node['consul']['version_purge'] }
end