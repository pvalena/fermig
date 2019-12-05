#!/usr/bin/ruby

# Packages which should be ignored during rebuild
IGNORED_PACKAGES = %w{
}

ignore = ARGV.grep(/^\-i=./).last

packages = `dnf repoquery -q --disablerepo='*' --enablerepo=rawhide-source --arch=src --qf '%{name}' --whatrequires 'ruby*'`
#packages = `dnf repoquery -q --disablerepo='*' --enablerepo=rawhide --enablerepo=rawhide-source --qf '%{name}' --whatrequires 'libruby*'`

exit $?.exitstatus unless $?.exitstatus.zero?

packages = packages.lines
packages.map!(&:strip)
packages.uniq!
packages.sort!
packages.delete('')

packages -= IGNORED_PACKAGES
packages -= ignore[3..-1].split(',') if ignore

puts packages
