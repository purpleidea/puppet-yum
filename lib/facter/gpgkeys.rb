# Simple yum module by James
# Copyright (C) 2012-2013+ James Shubin
# Written by James Shubin <james@shubin.ca>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# TODO: facter seems to only support lowercase fact names... BUG !
# careful for similar files that have identical lowercase names...
require 'facter'

max_size = 16384				# TODO: is this enough?
gpgkeydir = '/etc/pki/rpm-gpg/'			# TODO: get from global
valid_gpgkeydir = gpgkeydir.gsub(/\/$/, '')+'/'	# ensure trailing slash

found = {}						# create hash of values

if File.directory?(valid_gpgkeydir)
	Dir.glob(valid_gpgkeydir+'*').each do |f|
		# skip over files with , (commas) in their names...
		if not(f.include? ',')
			key = File.basename(f)
			val = File.open(f, 'r').read	# read into string

			# skip over overly large files...
			if val.length <= max_size
				found[key] = val
			# TODO: print warning on else...
			end
		end
	end
end

# now create the corresponding facts...
found.keys.each do |x|
	Facter.add('yum_repos_gpgkey_'+x) do
		#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
		setcode {
			found[x]
		}
	end
end

Facter.add('yum_repos_gpgkeys') do
	#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
	setcode {
		found.keys.join(',')
	}
end

