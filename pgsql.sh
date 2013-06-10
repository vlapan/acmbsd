#!/bin/sh -e

pgsql.check() {
	pkg.install.port postgresql-server databases/postgresql92-server
	#pkg.install.port p5-IO-Tty devel/p5-IO-Tty
	#pkg.install.port p5-Authen-Libwrap security/p5-Authen-Libwrap
	#pkg.install.port p5-DBI databases/p5-DBI
	#pkg.install.port p5-DBD-Pg databases/p5-DBD-Pg

	base.file.checkLine /boot/loader.conf kern.ipc.semmni kern.ipc.semmni=256
	base.file.checkLine /boot/loader.conf kern.ipc.semmns kern.ipc.semmns=512
	base.file.checkLine /boot/loader.conf kern.ipc.semmnu kern.ipc.semmnu=256

	base.file.checkLine /etc/sysctl.conf kern.ipc.shmall kern.ipc.shmall=32768
	base.file.checkLine /etc/sysctl.conf kern.ipc.shmmax kern.ipc.shmmax=134217728
	base.file.checkLine /etc/sysctl.conf kern.ipc.semmap kern.ipc.semmap=256
	base.file.checkLine /etc/sysctl.conf kern.ipc.shm_use_phys kern.ipc.shm_use_phys=1

	chown -R pgsql:pgsql /usr/local/share/postgresql
	chown -R pgsql:pgsql /usr/local/lib/postgresql
}