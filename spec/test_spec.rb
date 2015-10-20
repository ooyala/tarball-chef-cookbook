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

require_relative 'spec_helper.rb'

describe 'tarball::test' do
  let(:chef_run) do
    ChefSpec::SoloRunner.new.converge(described_recipe)
  end

  it 'creates /tmp/testing.tgz' do
    expect(chef_run).to create_cookbook_file('/tmp/testing.tgz')
  end

  it 'creates /tmp/testing.tar' do
    expect(chef_run).to create_cookbook_file('testing.tar')
  end

  it 'calls tarball' do
    expect(chef_run).to extract_tarball('/tmp/testing.tgz')
  end

  it 'calls tarball_x' do
    expect(chef_run).to extract_tarball_x('test2')
  end

  it 'removes /tmp/testing.tgz' do
    expect(chef_run).to delete_file('/tmp/testing.tgz')
  end

  it 'removes /tmp/testing.tar' do
    expect(chef_run).to \
      delete_file('testing.tar').with(path: '/tmp/testing.tar')
  end
end

# Run again, stepping into LWRP
describe 'tarball::test' do
  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      log_level: :error,
      step_into: %w(tarball tarball_x)
    ).converge(
      described_recipe
    )
  end

  before do
    allow(::File).to receive(:exists?).and_call_original
    allow(::File).to receive(:exists?).with('/tmp/testing.tgz').and_return true
    allow(::File).to receive(:exists?).with('/tmp/testing.tar').and_return true
    allow(::File).to receive(:open).and_call_original
    allow(::File).to receive(:open).with('/tmp/testing.tgz', 'rb').and_return \
      ::File.open(::File.join(::File.dirname(__FILE__),
                              '../files/default/testing.tgz'), 'rb')
    allow(::File).to receive(:open).with('/tmp/testing.tar', 'rb').and_return \
      ::File.open(::File.join(::File.dirname(__FILE__),
                              '../files/default/testing.tar'), 'rb')
  end

  it 'creates extraction dirs' do
    expect(chef_run).to create_directory('/tmp/testing1')
    expect(chef_run).to create_directory('/tmp/testing2')
  end

  it 'creates extracted files as expected' do
    %w(
      testing/a/2
      testing/a/b/1
      testing/e/h/3
      testing/e/h/4
      testing/e/h/5
      testing/e/h/6
      testing/e/h/i/j/k/l/m/n/o/p/q/r/3
    ).each do |f|
      expect(chef_run).to create_file("/tmp/testing1/#{f}")
      expect(chef_run).to create_file("/tmp/testing1/#{f}").with(mode: 0664)
      expect(chef_run).to create_file("/tmp/testing1/#{f}").with(owner: 'root')
      expect(chef_run).to create_file("/tmp/testing1/#{f}").with(group: 'root')
    end
  end

  it 'creates a bunch of directories' do
    %w( /tmp/testing1 /tmp/testing2 ).each do |t|
      %w(
        testing
        testing/a
        testing/a/b
        testing/a/b/c
        testing/a/b/d
        testing/e
        testing/e/f
        testing/e/g
        testing/e/h
        testing/e/h/i
        testing/e/h/i/j
        testing/e/h/i/j/k
        testing/e/h/i/j/k/l
        testing/e/h/i/j/k/l/m
        testing/e/h/i/j/k/l/m/n
        testing/e/h/i/j/k/l/m/n/o
        testing/e/h/i/j/k/l/m/n/o/p
        testing/e/h/i/j/k/l/m/n/o/p/q
        testing/e/h/i/j/k/l/m/n/o/p/q/r
      ).each do |d|
        expect(chef_run).to create_directory("#{t}/#{d}")
      end
    end
  end

  it 'creates another set of extracted files as expected' do
    %w( testing/a/b/1 ).each do |f|
      expect(chef_run).to create_file("/tmp/testing2/#{f}")
      expect(chef_run).to create_file("/tmp/testing2/#{f}").with(mode: 0644)
      expect(chef_run).to create_file("/tmp/testing2/#{f}").with(owner: 'root')
      expect(chef_run).to create_file("/tmp/testing2/#{f}").with(group: 'sys')
    end

    %w(
      testing/a/2
      testing/e/h/3
      testing/e/h/4
      testing/e/h/5
      testing/e/h/6
      testing/e/h/i/j/k/l/m/n/o/p/q/r/3
    ).each do |f|
      expect(chef_run).to_not create_file("/tmp/testing2/#{f}")
    end
  end

  it 'creates some symlinks' do
    %w(
      /tmp/testing1/testing/a/symlink_to_2
      /tmp/testing1/testing/a/symlink_to_3
      /tmp/testing2/testing/a/symlink_to_2
      /tmp/testing2/testing/a/symlink_to_3
    ).each do |l|
      expect(chef_run).to create_link(l)
    end
  end

  it 'creates some links' do
    %w(
      /tmp/testing1/testing/a/b/hardlink_to_1
      /tmp/testing2/testing/a/b/hardlink_to_1
    ).each do |l|
      expect(chef_run).to create_link(l).with_link_type(:hard)
    end
  end
end
