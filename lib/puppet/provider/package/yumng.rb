require 'puppet/util/package'
# This is a hack on
# https://github.com/puppetlabs/puppet/blob/master/lib/puppet/provider/package/yum.rb
#
# Inspired by
# https://github.com/seveas/yum-plugin-puppet/blob/master/lib/puppet/provider/package/yum3.rb

Puppet::Type.type(:package).provide :yumng, :parent => :yum, :source => :rpm do
  has_feature :install_options, :versionable
  commands :yum => "yum", :rpm => "rpm", :python => "python"
  attr_accessor :latest_info

  def lock_version(package, version=nil)
    pkg_string = "#{package}"
    if not version.nil?
      pkg_string = "#{pkg_string}-#{version}.*"
    end

    # A little protection against horrid dependancy loops
    # We heavily depend on versionlock so don't try and lock it... because w
    # will fail, hard.
    if package == 'yum' or package == 'yum-plugin-versionlock'
      self.debug "Skipping versionlock on #{package}"
      return
    end

    begin
      locks = yum('versionlock', '-q', 'list')
    rescue Puppet::ExecutionFailure => e
      fail('Could not read yum version locks')
    end

    # Loop though all the locks
    locks.split("\n").each do |lock|
      self.debug "Found versionlock entry => #{lock}"
      # Get the package string from the lock
      locked_pkg = lock.chomp.gsub(/^[0-9]+:(.*)\.\*$/, '\1')

      # Query the name and version from rpm
      # Saves painful parsing
      locked_pkg_name = locked_pkg.gsub(/^(.+)-([^-]+)-([^-]+)\.(\w+)$/, '\1')
      locked_pkg_version = locked_pkg.gsub(/^(.+)-([^-]+)-([^-]+)\.(\w+)$/, '\2-\3.\4')
      self.debug "Found versionlock info => #{locked_pkg_name}, #{locked_pkg_version}"

      # We have a lock
      if locked_pkg_name == package
        # Golden - we are locking the version we want
        if not version.nil? and locked_pkg_version == version
          self.debug "Package #{locked_pkg_name} locked to correct version: #{locked_pkg_version}"
          return

        # Boo - we are locking a different version
        # Delete the lock, we add it again below
        else
          self.debug "Deleting incorrect lock for #{locked_pkg_name} (#{lock})"
          yum('versionlock', '-q', 'delete', lock)
        end
      end
    end

    # If we got here we don't have a lock set
    # Lets add the lock to the right version
    # If version is nil, then we are using latest so don't lock
    if not version.nil?
      self.debug "Adding package lock for #{pkg_string}"
      yum('versionlock', '-q', 'add', "0:#{pkg_string}")
    end
  end

  def install
    should = @resource.should(:ensure)
    self.debug "Ensuring => #{should}"
    wanted = @resource[:name]
    operation = :install

  case should
  when true, false, Symbol
    # No version wanted
    should = nil
  else
    # Add the package version that's wanted
    wanted += "-#{should}"
    is = self.query
    if is && Puppet::Util::Package.versioncmp(should, is[:ensure]) < 0
      self.debug "Downgrading package #{@resource[:name]} from version #{is[:ensure]} to #{should}"
      operation = :downgrade
    end
  end

    # Lock the version we want in yum
    self.lock_version(@resource[:name], should)

    args = ["-d", "0", "-e", "0", "-y", install_options, operation, wanted].compact
    yum *args

    is = self.query
    raise Puppet::Error, "Could not find package #{self.name}" unless is
    raise Puppet::Error, "Failed to update to version #{should}, got version #{is[:ensure]} instead" if should && should != is[:ensure]
  end
end
