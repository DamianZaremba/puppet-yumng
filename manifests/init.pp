# Hacked yum package provider to enforce version locks in yum land
# Ensures we can `yum update` a box without bypassing puppet's enforced versions
class yumng {
    # We heavily depend on versionlock
    package {
        ['yum', 'yum-plugin-versionlock']:
            ensure  => latest;
    }
}

# Ensure we run before anything else
Class['Yumng'] -> Stage['main']
