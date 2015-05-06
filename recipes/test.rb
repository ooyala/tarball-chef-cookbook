# Copyright 2015 Ooyala, Inc. All rights reserved.
#
# This file is licensed under the MIT License (the "License");
# you may not use this file except in compliance with the
# License. You may obtain a copy of the License at
# http://opensource.org/licenses/MIT
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.  See the License for the specific language governing
# permissions and limitations under the License.

include_recipe 'tarball::default'

cookbook_file 'testing.tgz' do
  path '/tmp/testing.tgz'
  action :create
end

tarball '/tmp/testing.tgz' do
  destination '/tmp/testing1'
  owner 'root'
  group 'root'
  umask 002
  action :extract
end

file '/tmp/testing.tgz' do
  action :delete
end

file = 'testing.tar'

cookbook_file 'testing.tar' do
  path "/tmp/#{file}"
  action :create
end

tarball_x 'test2' do
  source lazy { "/tmp/#{file}" }
  destination '/tmp/testing2'
  owner 'root'
  group 'sys'
  extract_list ['1', '/.*_to_.*/']
  action :extract
end

file 'testing.tar' do
  path "/tmp/#{file}"
  action :delete
end
