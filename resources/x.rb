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

actions :extract
default_action :extract if defined?(default_action)

provides :tarball if self.respond_to?('provides')

def initialize(*args)
  super
  @created_files = created_files
end

attribute :name, kind_of: String, name_attribute: true
attribute :source, kind_of: String
attribute :destination, kind_of: String, required: true
attribute :extract_list, kind_of: [Array, String]
attribute :owner, kind_of: String
attribute :group, kind_of: String
attribute :umask, kind_of: [String, Integer], default: 022
attribute :overwrite, kind_of: [TrueClass, FalseClass], default: true

# This attribute is *not* meant to be passed as in the tarball_x block
attribute :created_files, kind_of: Array, default: []
