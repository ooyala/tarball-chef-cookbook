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

file = 'testing.tgz'

cookbook_file file do
  path "/tmp/#{file}"
  action :create
end

tarball "/tmp/#{file}" do
  destination '/tmp/testing1'
  owner 'root'
  group 'root'
  umask 002
  action :extract
end

file "/tmp/#{file}" do
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
  mode '0755'
  extract_list ['**/1', '**/*_to_*']
  action :extract
end

tarball_x 'test3 excluding' do
  source lazy { "/tmp/#{file}" }
  destination '/tmp/testing3'
  owner 'root'
  group 'root'
  exclude ['**/1', 'testing/a/2', 'testing/**/3', '**/q/**']
end

tarball_x 'test4 strip_components' do
  source "/tmp/#{file}"
  destination '/tmp/testing4'
  strip_components 2
end

file 'testing.tar' do
  path "/tmp/#{file}"
  action :delete
end
