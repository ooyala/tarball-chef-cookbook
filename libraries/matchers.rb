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

# Custom ChefSpec::Matchers for tarball LWRP

if defined?(ChefSpec)
  def extract_tarball_x(name)
    ChefSpec::Matchers::ResourceMatcher.new(:tarball_x, :extract, name)
  end

  def extract_tarball(name)
    ChefSpec::Matchers::ResourceMatcher.new(:tarball, :extract, name)
  end
end
