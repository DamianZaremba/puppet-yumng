# Hacked yum package provider to enforce version locks in yum land
# Ensures we can `yum update` a box without bypassing puppet's enforced versions
class yumng {
  # We heavily depend on versionlock
  package {
    ['yum', 'yum-plugin-versionlock']:
      ensure  => latest;
  }

  # Config file
  file {
    '/etc/yum/pluginconf.d/versionlock.conf':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      source  => 'puppet:///modules/yumng/versionlock.conf',
      require => Package['yum-plugin-versionlock'];

    '/etc/yum/pluginconf.d/versionlock.list':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      replace => false,
      require => Package['yum-plugin-versionlock'];
  }
}