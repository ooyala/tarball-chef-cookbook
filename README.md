tarball
=======

Description: tar file extraction resource provider.

[![Build Status](https://travis-ci.org/ooyala/tarball-chef-cookbook.svg?branch=master)](https://travis-ci.org/ooyala/tarball-chef-cookbook)

[Source on GitHub](https://github.com/ooyala/tarball-chef-cookbook)

Features
--------
* Does not rely on system tar (ruby only!)
* Automatically handles gzipped archives
* Can change mode/ownership
* Can select specific files only
* Can exclude files
* Can emulate `--strip-components`
* Can handle:
  * regular files
  * directories
  * symbolic links
  * hard links (provided the source file already exists; otherwise the
    hard link creation is skipped)

Supported tar formats
---------------------
* POSIX
* Some GNU tar extensions (LONGNAME, LONGLINK)
* Other tar formats will probably extract files without issue, but some
  metadata may not be handled as expected.  If needed, please give a
  sample tar file and the tar program, version, and OS used to create
  archive, if possible, when requesting support.

Limitations
-----------
* Ignores FIFOs, block devices, etc.
* Compressions other than zlib/gzip not currently supported
* May or may not correctly handle non-standard blocksizes

Recipes
-------
* default.rb - to pull in resource provider for use in other cookbooks
* test.rb - recipe to use for testing only

Usage
-----
```
include_recipe 'tarball::default'

# Fetch the tarball if it's not a local file
remote_file '/tmp/some_archive.tgz' do
  source 'http://example.com/some_archive.tgz'
end

# I can use tarball_x "file" do ...
tarball_x '/tmp/some_archive.tgz' do
  destination '/opt/my_app_path/conf'   # Will be created if missing
  owner 'root'
  group 'root'
  extract_list [ 'properties/*.conf' ]  # Will extract all *.conf files found within the properties dir in the tarball
  strip_components 1                    # Will strip the first directory (i.e. `properties/`) so that the *.conf files will be placed directly in `/opt/my_app_path/conf`
  mode '0644'                           # Will apply these permissions to all files extracted (overwrites the permissions within the tarball)
  action :extract
end

# I can also just use tarball  "file" do ...
tarball '/tmp/some_other_archive.tar' do
  destination '/opt/somewhere/else'
  exclude [ '.gitignore' ]              # Will extract everything, but exclude the .gitfile file that got packaged
  umask 002                             # Will apply the umask to perms in archive, while retaining their existing permissions within the tarball
  action :extract
end

```


It will throw exceptions derived form StandardError in most cases
(permissions errors, etc.), so you may want to wrap the block in a
begin/rescue.

```
begin
  tarball '/tarball_path.tgz/' do
    ...
  end
rescue StandardError => e
  log e.message
  ...
end
```
