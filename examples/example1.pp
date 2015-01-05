# causes the equivalent of /usr/bin/yum -y groupinstall "Development tools"
# also works with normal rpm packages

yum::package { '@Development tools':
	ensure => present,
}

