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

require 'zlib'
require 'fileutils'
require 'rubygems/package'

def whyrun_supported?
  true
end

use_inline_resources

def t_open(tarfile)
  ::File.open(tarfile, 'rb')
rescue StandardError => e
  Chef::Log.warn e.message
  raise e
end

def t_stream(f)
  tgz = Zlib::GzipReader.new(f)
rescue Zlib::GzipFile::Error
  # Not gzipped
  f.rewind
  f
else
  tgz
end

def mkdestdir(tarball)
  directory tarball.destination do
    action :create
    owner tarball.owner
    group tarball.group
    # We use octal here for UNIX file mode readability, but we could just
    # as easily have used decimal 511 and gotten the correct behavior
    mode 0777 & ~tarball.umask.to_i
    recursive true
    tarball.updated_by_last_action(true)
  end
end

# Placeholder method in case someone actually needs PAX support
def pax_handler(pax)
  Chef::Log.debug("PAX: #{pax}") if pax
end

def t_mkdir(tarball, entry, pax, name = nil)
  pax_handler(pax)
  if name.nil?
    dir = ::File.join(tarball.destination, entry.full_name).gsub(%r{/$}, '')
  else
    dir = name
  end
  directory dir do
    action :create
    owner tarball.owner || entry.header.uid
    group tarball.group || entry.header.gid
    mode { (fix_mode(entry.header.mode) | 0111) & ~tarball.umask.to_i }
    recursive true
  end
end

def get_target(tarball, entry, type)
  if type == :symbolic
    entry.header.linkname
  else
    ::File.join(tarball.destination, entry.header.linkname)
  end
end

def t_link(tarball, entry, type, pax, longname)
  pax_handler(pax)
  dir = tarball.destination
  t_mkdir(tarball, entry, pax, dir) unless ::File.exist?(dir)
  target = get_target(tarball, entry, type)

  if type == :hard &&
     !(::File.exist?(target) || tarball.created_files.include?(target))
    Chef::Log.debug "Skipping #{entry.full_name}: #{target} not found"
    return
  end

  src = ::File.join(dir, longname || entry.full_name)
  t_mkdir(tarball, entry, pax, ::File.dirname(src)) \
      unless ::File.directory?(::File.dirname(src))
  link src do
    to target
    owner tarball.owner || entry.header.uid
    link_type type
    action :create
  end
end

def t_file(tarball, entry, pax, longname)
  pax_handler(pax)
  file_name = longname || entry.full_name
  Chef::Log.info "Creating file #{file_name}"
  fqpn = ::File.join(tarball.destination, file_name)
  t_mkdir(tarball, entry, pax, ::File.dirname(fqpn)) \
      unless ::File.directory?(::File.dirname(fqpn))
  file fqpn do
    action :create
    owner tarball.owner || entry.header.uid
    group tarball.group || entry.header.gid
    mode fix_mode(entry.header.mode) & ~tarball.umask.to_i
    sensitive true
    content entry.read
  end
  tarball.created_files << fqpn
end

def on_list?(name, tarball)
  Array(tarball.extract_list).each do |r|
    return true if ::File.basename(name).match(Regexp.quote(r))
  end
  false
end

def wanted?(name, tarball, type)
  if ::File.exist?(::File.join(tarball.destination, name)) &&
     tarball.overwrite == false
    false
  elsif %w(2 5 L).include?(type)
    true
  elsif tarball.extract_list
    on_list?(name, tarball)
  else
    true
  end
end

def t_extraction(tar, tarball)
  # pax and longname track extended types that span more than one tar entry
  pax = nil
  longname = nil
  Gem::Package::TarReader.new(tar).each do |ent|
    next unless wanted?(ent.full_name, tarball, ent.header.typeflag)
    Chef::Log.info "Next tar entry: #{ent.full_name}"
    case ent.header.typeflag
    when '1'
      t_link(tarball, ent, :hard, pax, longname)
      pax = nil
      longname = nil
    when '2'
      t_link(tarball, ent, :symbolic, pax, longname)
      pax = nil
      longname = nil
    when '5'
      t_mkdir(tarball, ent, pax)
      pax = nil
      longname = nil
    when '3', '4', '6', '7'
      Chef::Log.debug "Can't handle type for #{ent.full_name}: skipping"
      pax = nil
      longname = nil
    when 'x', 'g'
      Chef::Log.debug 'PaxHeader'
      pax = ent
      longname = nil
    when 'L', 'K'
      longname = ent.read.strip
      Chef::Log.debug "Using LONG(NAME|LINK) #{longname}"
      pax = nil
    else
      t_file(tarball, ent, pax, longname)
      pax = nil
      longname = nil
    end
  end
end

def fix_mode(mode)
  # GNU tar doesn't store the mode POSIX style, so we fix it
  mode > 07777.to_i ? mode.to_s(8).slice(-4, 4).to_i(8) : mode
end

provides :tarball if self.respond_to?('provides')

action :extract do
  tarball = new_resource
  Chef::Log.info "TARFILE: #{tarball.source || tarball.name}"
  tar = t_open(tarball.source || tarball.name)
  tar = t_stream(tar)
  mkdestdir(tarball)
  t_extraction(tar, tarball)
  new_resource.updated_by_last_action(true)
end
