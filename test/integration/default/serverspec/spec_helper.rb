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

require 'serverspec'
require 'pathname'
require 'json'

include Serverspec::Helper::Exec
include Serverspec::Helper::DetectOS

RSpec.configure do |c|
  c.before :all do
    c.path = '/bin:/usr/bin:/sbin:/usr/sbin'
  end
end

# This file gets created by the test-helper recipe.  Make sure it's at the
# end of your run list!
$node = ::JSON.parse(File.read('/tmp/serverspec/node.json'))
