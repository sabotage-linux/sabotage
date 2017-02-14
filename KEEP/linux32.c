#include <sys/personality.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#ifdef USE_LIBULZ
#include <ulz/stdio-repl.h>
#endif


#if !defined(_Noreturn) && __STDC_VERSION__+0 < 201112L
#ifdef __GNUC__
#define _Noreturn __attribute__((noreturn))
#else
#define _Noreturn
#endif
#endif

#ifndef PER_LINUX32
#define PER_LINUX32 8
#endif

static _Noreturn void die(const char *msg) {
	dprintf(2, msg);
	exit(1);
}

static _Noreturn void usage(void) {
	die("usage: linux32 command [options...]\n"
	    "executes command with options in 32bit linux mode\n"
	    "(uname will report 32bit arch)\n");
}

int main(int argc, char** argv) {
	if(argc == 1) usage();
	if(personality(PER_LINUX32) == -1) die("could not set 32bit persona");
	if(execvp(argv[1], &argv[1]) == -1) perror("execvp");
	return 1;
}

