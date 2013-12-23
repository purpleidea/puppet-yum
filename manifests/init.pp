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

# NOTE: using this module can cause any unmanaged repos to be purged!

class yum() {
	# this allows different classes to include a non-exclusive yum
	class { '::yum::repos':
		exclusive => false,
	}
}

class yum::repos(
	$exclusive = false	# do we allow exclusive management or not ?
) {
	file { '/etc/yum.repos.d/':
		ensure => directory,	# make sure this is a directory
		recurse => true,	# recursively manage directory
		purge => $exclusive,	# purge all unmanaged files or not ?
		force => true,		# also purge subdirs and links
		owner => root,
		group => root,
		mode => 644,		# u=rw,go=r
	}
}

define yum::repos::repo(
	$baseurl = '',		# This can be used instead of or with the mirrorlist option.
	$mirrorlist = '',	# This can be used instead of or with the baseurl option.
	$enabled = true,
	$gpgcheck = true,
	$gpgkeys = '',		# single str or array
	$namespace = '',	# use to enable macaronic magic with this string
	$priority = 99,		# TODO: cobbler seems to add this option with 99 as default. what should i do ?
	$includepkgs = [],	# This is a list of packages you want to use from a repository. If this option lists only one package then that is all yum will ever see from the repository.
	$excludepkgs = [],	# This is a list of packages to never include or update from this repo.
	$ensure = present
) {
	include 'yum::repos'

	$bool_enabled = $enabled ? {
		true => '1',
		default => '0',
	}

	$bool_gpgcheck = $gpgcheck ? {
		true => '1',
		default => '0',
	}

	file { "/etc/yum.repos.d/${name}.repo":
		content => template('yum/repo.erb'),
		owner => root,
		group => root,
		mode => 644,	# should be readable by all so users can yum X
		require => File['/etc/yum.repos.d/'],
		ensure => $ensure,
	}
}

# NOTE: this define does not depend on the other classes or define's
# NOTE: this define is used to create exported resources of gpgkeys!
# NOTE: this define uses the custom yum_repos_* facts in this module
define yum::repos::gpgkey(
	$tag = undef,
	$basepath = '/etc/pki/rpm-gpg/'
) {
	$f = sprintf("%s/${name}", regsubst($basepath, '\/$', ''))	# slash
	$failure = "# Problem getting fact!\n"
	# downcase is required because fact names can only be lowercase; weird!
	# this does a fact lookup and returns an error message if it is missing
	$content = inline_template("<%= scope.to_hash.fetch('yum_repos_gpgkey_${name}'.downcase, '${failure}') %>")
	if "${content}" == "${failure}" {
		warning("Problem getting fact: '${name}'.")
	}

	@@file { "${f}":
		tag => "${tag}",
		content => "${content}",
		owner => root, group => root, mode => 644, backup => false,
		ensure => present,
	}
}

# collect the keys from the above defines that have the same tag...
class yum::repos::gpgkey_collect(
	$tag = undef
) {
	File <<| tag == "${tag}" |>>
}

# this installed packages or package groups, which the package type doesn't :(
define yum::package(
	$ensure = present
) {
	$deleted = delete("${name}", '@')
	if "@${deleted}" == "${name}" {	# string started with @
		$valid_group = "${deleted}"
		$installed = "/usr/bin/yum grouplist '${valid_group}' | /bin/grep -q '^Installed Groups'"
		exec { "yum-groupinstall-${name}":
			command => $ensure ? {
				absent => "/usr/bin/yum -y groupremove '${valid_group}'",
				default => "/usr/bin/yum -y groupinstall '${valid_group}'",
			},
			logoutput => on_failure,
			unless  => $ensure ? {
				absent => undef,
				default => "${installed}",
			},
			onlyif  => $ensure ? {
				absent => "${installed}",
				default => undef,
			},
		}
	} elsif "${deleted}" == "${name}" {	# no @ was present
		package { "${name}":
			ensure => $ensure,
		}
	} else {
		fail("The package or group name of '${name}' is invalid.")
	}
}

