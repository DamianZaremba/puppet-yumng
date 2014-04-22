yumng
=====
Yum package provider that supports proper version locking using the versionlock
yum plugin.

Tested on
---------
* Puppet 3.4/3.5
* CentOS 6.5 (yum-3.2.29-43.el6.centos.noarch, yum-plugin-versionlock-1.1.30-17.el6_5.noarch)

Usage
-----
* Put this module in modules/yumng
* In your site manifest or base class include the following

  class {
    'yumng':
      stage => 'setup';
  }
  Package { provider => 'yumng' }

Why?
----
In a puppet environment where versions are enforced for packages it is nearly
impossible to `yum update` a box - you either change the package version,
which puppet tries to change back, or break things.

This uses the versionlock plugin to tell yum a package is locked to a certain
version, meaning you can `yum update` all day long without bypassing puppet.

License
-------
Copyright 2014 Damian Zaremba

yumng is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

yumng is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with yumng.  If not, see <http://www.gnu.org/licenses/>.
