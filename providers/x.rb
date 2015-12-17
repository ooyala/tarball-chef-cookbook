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

def t_stream(tarball)
  tarball_gz = Zlib::GzipReader.new(tarball)
rescue Zlib::GzipFile::Error
  # Not gzipped
  tarball.rewind
  tarball
else
  tarball_gz
end

def mkdir(destination, owner = nil, group = nil, mode = nil)
  return if destination.nil?
  directory destination do
    action :create
    owner owner unless owner.nil?
    group group unless group.nil?
    mode mode unless mode.nil?
    recursive true
  end
end

def mkdestdir(tarball_resource)
  dest = tarball_resource.destination
  owner = tarball_resource.owner
  group = tarball_resource.group
  # We use octal here for UNIX file mode readability, but we could just
  # as easily have used decimal 511 and gotten the correct behavior
  mode = 0777 & ~tarball_resource.umask.to_i
  mkdir(dest, owner, group, mode)
  tarball_resource.updated_by_last_action(true)
end

# Placeholder method in case someone actually needs PAX support
def pax_handler(pax)
  Chef::Log.debug("PAX: #{pax}") if pax
end

def t_mkdir(tarball_resource, entry, pax, name = nil)
  pax_handler(pax)
  if name.nil?
    dir = get_tar_entry_path(tarball_resource, entry.full_name)
    dir = ::File.join(tarball_resource.destination, dir)
    dir = dir.gsub(%r{/$}, '')
  else
    dir = name
  end
  return if dir.empty? || ::File.directory?(dir)
  owner = tarball_resource.owner || entry.header.uid
  group = tarball_resource.group || entry.header.gid
  mode = lambda do
    (fix_mode(entry.header.mode) | 0111) & ~tarball_resource.umask.to_i
  end.call

  mkdir(dir, owner, group, mode)
end

def get_target(tarball_resource, entry, type)
  if type == :symbolic
    entry.header.linkname
  else
    target = get_tar_entry_path(tarball_resource, entry.header.linkname)
    ::File.join(tarball_resource.destination, target)
  end
end

def get_tar_entry_path(tarball_resource, full_path)
  if tarball_resource.strip_components
    paths = Pathname.new(full_path)
            .each_filename
            .drop(tarball_resource.strip_components)
    if paths.empty?
      full_path = ""
    else
      full_path = ::File.join(paths)
    end
  end
  full_path
end

def t_link(tarball_resource, entry, type, pax, longname)
  pax_handler(pax)
  dir = tarball_resource.destination
  t_mkdir(tarball_resource, entry, pax, dir)
  target = get_target(tarball_resource, entry, type)

  if type == :hard &&
     !(::File.exist?(target) || tarball_resource.created_files.include?(target))
    Chef::Log.debug "Skipping #{entry.full_name}: #{target} not found"
    return
  end

  filename = longname || entry.full_name
  src = get_tar_entry_path(tarball_resource, filename)
  return if src.empty?
  src = ::File.join(dir, src)
  t_mkdir(tarball_resource, entry, pax, ::File.dirname(src))
  link src do
    to target
    owner tarball_resource.owner || entry.header.uid
    link_type type
    action :create
  end
end

def t_file(tarball_resource, entry, pax, longname)
  pax_handler(pax)
  fqpn = longname || entry.full_name
  fqpn = get_tar_entry_path(tarball_resource, fqpn)
  return if fqpn.empty?
  fqpn = ::File.join(tarball_resource.destination, fqpn)
  Chef::Log.info "Creating file #{fqpn}"
  t_mkdir(tarball_resource, entry, pax, ::File.dirname(fqpn))
  file fqpn do
    action :create
    owner tarball_resource.owner || entry.header.uid
    group tarball_resource.group || entry.header.gid
    mode fix_mode(entry.header.mode) & ~tarball_resource.umask.to_i
    sensitive true
    content entry.read
  end
  tarball_resource.created_files << fqpn
end

def exclude?(filename, tarball_resource)
  Array(tarball_resource.exclude).each do |r|
    return true if ::File.fnmatch?(r, filename)
  end
  false
end

def on_list?(filename, tarball_resource)
  Array(tarball_resource.extract_list).each do |r|
    return true if ::File.fnmatch?(r, filename)
  end
  false
end

def wanted?(filename, tarball_resource, type)
  if tarball_resource.exclude
    return false if exclude?(filename, tarball_resource)
  end
  if ::File.exist?(::File.join(tarball_resource.destination, filename)) &&
     tarball_resource.overwrite == false
    false
  elsif %w(2 5 L).include?(type)
    true
  elsif tarball_resource.extract_list
    on_list?(filename, tarball_resource)
  else
    true
  end
end

def t_extraction(tarball, tarball_resource)
  # pax and longname track extended types that span more than one tar entry
  pax = nil
  longname = nil
  Gem::Package::TarReader.new(tarball).each do |entry|
    unless wanted?(entry.full_name, tarball_resource, entry.header.typeflag)
      next
    end
    Chef::Log.info "Next tar entry: #{entry.full_name}"
    case entry.header.typeflag
    when '1'
      t_link(tarball_resource, entry, :hard, pax, longname)
      pax = nil
      longname = nil
    when '2'
      t_link(tarball_resource, entry, :symbolic, pax, longname)
      pax = nil
      longname = nil
    when '5'
      t_mkdir(tarball_resource, entry, pax)
      pax = nil
      longname = nil
    when '3', '4', '6', '7'
      Chef::Log.debug "Can't handle type for #{entry.full_name}: skipping"
      pax = nil
      longname = nil
    when 'x', 'g'
      Chef::Log.debug 'PaxHeader'
      pax = entry
      longname = nil
    when 'L', 'K'
      longname = entry.read.strip
      Chef::Log.debug "Using LONG(NAME|LINK) #{longname}"
      pax = nil
    else
      t_file(tarball_resource, entry, pax, longname)
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
  tarball_resource = new_resource
  Chef::Log.info "TARFILE: #{tarball_resource.source || tarball_resource.name}"
  tarball = t_open(tarball_resource.source || tarball_resource.name)
  tarball = t_stream(tarball)
  mkdestdir(tarball_resource)
  t_extraction(tarball, tarball_resource)
  new_resource.updated_by_last_action(true)
end
