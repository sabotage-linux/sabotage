#include <unistd.h>
#include <stdio.h>
static int usage(void) {
	dprintf(2, "usage: unlink file\n");
	return 1;
}

int main(int argc, char** argv) {
	if(argc != 2) return usage();
	if(unlink(argv[1]) == -1) {
		perror("unlink");
		return 1;
	}
	return 0;
}
