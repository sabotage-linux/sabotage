#define _GNU_SOURCE
#include <sched.h>
#include <stdio.h>
#include <unistd.h>
#include <signal.h>
#include <stdlib.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/mount.h>
#include <stdio.h>
#define chk(X) if((X) == -1) { perror(#X); exit(1); }

int main(int argc, char **argv)
{
	uid_t uid = getuid();
	uid_t gid = getgid();

	char *tarballs=getenv("C");
	if(!tarballs) tarballs = "./tarballs";

	chk(unshare(CLONE_NEWUSER|CLONE_NEWNS));

	char buf[32];

	int fd = open("/proc/self/uid_map", O_RDWR);
	write(fd, buf, snprintf(buf, sizeof buf, "0 %u 1\n", uid));
	close(fd);

	fd = open("/proc/self/setgroups", O_RDWR);
	write(fd, buf, snprintf(buf, sizeof buf, "deny\n"));
	close(fd);

	fd = open("/proc/self/gid_map", O_RDWR);
	write(fd, buf, snprintf(buf, sizeof buf, "0 %u 1\n", gid));
	close(fd);

	chdir(argv[1]);
	chk(mount("/dev", "./dev", 0, MS_BIND|MS_REC, 0));
	chk(mount("/proc", "./proc", 0, MS_BIND|MS_REC, 0));
	chk(mount(tarballs, "./src/tarballs", 0, MS_BIND, 0));

	chk(chroot("."));

	chk(execv(argv[2], argv+2));
}
