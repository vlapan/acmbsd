#!/bin/sh -e

pgsql.check() {
	base.file.checkLine /boot/loader.conf kern.ipc.semmni kern.ipc.semmni=256
	base.file.checkLine /boot/loader.conf kern.ipc.semmns kern.ipc.semmns=512
	base.file.checkLine /boot/loader.conf kern.ipc.semmnu kern.ipc.semmnu=256

	base.file.checkLine /etc/sysctl.conf kern.ipc.shmall kern.ipc.shmall=32768
	base.file.checkLine /etc/sysctl.conf kern.ipc.shmmax kern.ipc.shmmax=134217728
	base.file.checkLine /etc/sysctl.conf kern.ipc.semmap kern.ipc.semmap=256
	base.file.checkLine /etc/sysctl.conf kern.ipc.shm_use_phys kern.ipc.shm_use_phys=1

	pkg.install postgresql*-server databases/postgresql94-server

	chown -R pgsql:pgsql /usr/local/share/postgresql
	chown -R pgsql:pgsql /usr/local/lib/postgresql
}
