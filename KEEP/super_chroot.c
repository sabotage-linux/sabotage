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
#include <string.h>

#define chk(X) if((X) == -1) { perror(#X); exit(1); }

static void bindmount2(char *src, char*dst, int flags) {
	if(mount(src, dst, 0, MS_BIND|flags, 0) == -1) {
		fprintf(stderr, "failed to mount %s to %s: %m\n", src, dst);
		exit(1);
	}
}
static void bindmount1(char *exp, int flags) {
	char *p = strchr(exp, ':');
	if(!p) {
		fprintf(stderr, "missing : char in expression\n");
		exit(1);
	}
	*p = 0;
	bindmount2(exp, p+1, flags);
}

static int usage(void) {
	fprintf(stderr,
		"usage: PROG [-b src:dest] DIR COMMAND [ARGS...]\n\n"
		"chroots to DIR executing COMMAND ARGS using kernel's USER_NS.\n"
		"/dev and /proc will be mounted automatically.\n\n"
		"-b src:dest   : add a bindmount to the rootfs.\n"
		"                one or more -b options can be specified.\n"
		"\n"
		"example: PROG -b /dev/shm:./tmp rootdir /bin/sh\n"
	);
	return 1;
}

#define MAXBINDS 16

int main(int argc, char **argv)
{
	int c, a;
	static char* binds[MAXBINDS];
	int bindc = 0;

	while((c = getopt(argc, argv, ":b:")) != -1) switch (c) {
	case 'b':
		binds[bindc++] = optarg;
		if(bindc == MAXBINDS) {
			fprintf(stderr, "number of binds exceeds MAXBINDS\n");
			exit(1);
		}
		break;
	default:
		return usage();
	}

	a = optind;
	if(argc < a+2) return usage();

	uid_t uid = getuid();
	uid_t gid = getgid();

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

	chdir(argv[a]);

	bindmount2("/dev", "./dev", MS_REC);
	bindmount2("/proc", "./proc", MS_REC);

	for(c = 0; c < bindc; ++c)
		bindmount1(binds[c], 0);

	chk(chroot("."));

	++a;
	chk(execv(argv[a], argv+a));
}
