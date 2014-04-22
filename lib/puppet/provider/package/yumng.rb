require 'puppet/util/package'
# This is a hack on
# https://github.com/seveas/yum-plugin-puppet/blob/master/lib/puppet/provider/package/yum3.rb
# https://github.com/puppetlabs/puppet/blob/master/lib/puppet/provider/package/yum.rb

Puppet::Type.type(:package).provide :yumng, :parent => :yum, :source => :rpm do
  has_feature :install_options, :versionable
  commands :yum => "yum", :rpm => "rpm", :python => "python"
  attr_accessor :latest_info

  def self.lock_version(package, version=nil)
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

    # Create the file if it doesn't exist (just in case)
    if not File.exists?('/etc/yum/pluginconf.d/versionlock.list')
      File.open('/etc/yum/pluginconf.d/versionlock.list', 'w') {} 
    end

    # Read the locks in
    begin
      fh = File.open('/etc/yum/pluginconf.d/versionlock.list', 'r')
    rescue Puppet::ExecutionFailure => e
      fail('Could not read yum version locks')
    end

    # Loop though all the locks and add them to the array
    locks = []
    while lock = fh.gets
      # Skip comments/blank lines
      next if lock =~ /^(\s*|#.*)$/

      self.debug "Found versionlock entry => #{lock}"
      # Get the package string from the lock
      locked_pkg = lock.chomp.gsub(/^[0-9]+:(.*)\.\*$/, '\1')

      # Query the name and version from rpm
      # Saves painful parsing
      locked_pkg_name = locked_pkg.gsub(/^(.+)-([^-]+)-([^-]+)\.(\w+)$/, '\1')
      locked_pkg_version = locked_pkg.gsub(/^(.+)-([^-]+)-([^-]+)\.(\w+)$/, '\2-\3.\4')
      self.debug "Found versionlock info => #{locked_pkg_name}, #{locked_pkg_version}"

      # We have a lock set
      if locked_pkg_name == package
        # Golden - we are locking the version we want
        if not version.nil? and locked_pkg_version == version
          self.debug "Package #{locked_pkg_name} locked to correct version: #{locked_pkg_version}"
          return

        # Boo - we are locking a different version
        # Delete the lock, we add it again below
        else
          self.debug "Ignoring incorrect lock for #{locked_pkg_name} (#{lock})"
          next
        end
      end

      self.debug "Adding lock #{lock} to the locks"
      locks << lock
    end
    fh.close

    # If we got here we don't have a lock set
    # Lets add the lock to the right version
    if not version.nil?
      locks << "0:#{pkg_string}"
    end

    # Write the locks out
    # We do this regardless of the above as we might be deleting a lock
    locks_data = locks.join("\n")
    self.debug "Writing out locks:\n#{locks_data}"
    begin
      File.open('/etc/yum/pluginconf.d/versionlock.list', 'w') do |fh|
        fh.write(locks_data)
        fh.close
      end
    rescue Puppet::ExecutionFailure => e
      fail('Could not write yum version locks')
    end
  end

  def self.prefetch(packages)
    raise Puppet::Error, "The yum provider can only be used as root" if Process.euid != 0
    super

    # Create the locks
    packages.each do |name, package|
      should = package.should(:ensure).to_s
      if [true, false, 'latest', 'present'].include?(should)
        should = nil
      end

      self.lock_version(name, should)
    end

    # Return unless using latest
    return unless packages.detect { |name, package| package.should(:ensure) == :latest }

    # collect our 'latest' info
    updates = {}
    python(self::YUMHELPER).each_line do |l|
      l.chomp!
      next if l.empty?
      if l[0,4] == "_pkg"
        hash = nevra_to_hash(l[5..-1])
        [hash[:name], "#{hash[:name]}.#{hash[:arch]}"].each  do |n|
          updates[n] ||= []
          updates[n] << hash
        end
      end
    end

    # Add our 'latest' info to the providers.
    packages.each do |name, package|
      if info = updates[package[:name]]
        package.provider.latest_info = info[0]
      end
    end
  end
end
