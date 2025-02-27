#define _GNU_SOURCE /* for struct dirent d_type values */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>
#include <assert.h>
#include <errno.h>
#include <fcntl.h>

#define ARRAY_SIZE(X) sizeof(X)/sizeof(X[0])

static int overwrite_on_copy = 0, verbose = 0;
static char* staging_dir;
static char* R;
static char* prefix;

#define errorp(F, FMT, ...) fprintf(stderr, F ": " FMT " (%s)\n", __VA_ARGS__, strerror(errno))
#define makedir(X) mkdir(X, S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH)

static int isdir(char*fn) {
	DIR *d = opendir(fn);
	if(!d) return 0;
	closedir(d);
	return 1;
}

static int linkdir(char*src, char*dst, char*back_src) {
	if(!isdir(dst) && makedir(dst)) {
		errorp("mkdir", "%s", dst);
		return 1;
	}
	int ret = 0;
	DIR *dir = opendir(src);
	if(!dir) {
		fprintf(stderr, "error: failed to open dir %s\n", src);
		return 1;
	}
	struct dirent *ent;
	while((ent = readdir(dir))) {
		char *ibas = ent->d_name;
		if(ent->d_type == DT_DIR && ibas[0] == '.' &&
		   (!ibas[1] || (ibas[1] == '.' && !ibas[2])))
			continue;
		char sfull[512], dfull[512], bfull[512];
		snprintf(sfull, sizeof sfull, "%s/%s", src, ent->d_name);
		snprintf(dfull, sizeof dfull, "%s/%s", dst, ent->d_name);
		char *srcbas = strrchr(src, '/');
		assert(srcbas);
		srcbas+=1;
		if(ent->d_type == DT_DIR) {
			snprintf(bfull, sizeof bfull, "../%s/%s", back_src, srcbas);
			ret |= linkdir(sfull, dfull, bfull);
		} else if(ent->d_type == DT_LNK || ent->d_type == DT_REG) {
			struct stat st;
			int sok = lstat(dfull, &st) == 0;
			if(sok && S_ISDIR(st.st_mode)) {
				fprintf(stderr, "WARNING: LN OVER DIR\n");
				exit(1);
			}
			unlink(dfull); // ignore error

			snprintf(bfull, sizeof bfull, "%s/%s/%s", back_src, srcbas, ibas);
			if(verbose) fprintf(stdout, "linking %s -> %s\n", bfull, dfull);

			if(symlink(bfull, dfull)) {
				errorp("symlink", "%s -> %s", bfull, dfull);
				ret |= 1;
			}
		} else {
			if(verbose) fprintf(stderr, "ignoring unknown file %s\n", sfull);
		}
	}
	closedir(dir);
	return ret;
}

static int fileexists(char *f) {
	struct stat st;
	return stat(f, &st) == 0;
}

/* returns 0 if successfull, -1 else. */
static int copyfile(char* src, char* dst) {
	int fds, fdd = -1;
	int err_close;
	char* err_data;
	char* err_func;
	struct stat st;

	uint64_t done = 0;
	char buf[64*1024];

	if((fds = open(src, O_RDONLY)) == -1) {
		err_data = src;
		err_func = "open";
		err_close = 0;

	error:
		fprintf(stderr, "copy error (%s): %s failed (%s)\n", err_data, err_func, strerror(errno));
		if(err_close) {
			close(fds);
			err_close--;
			if(err_close && fdd != -1) {
				close(fdd);
				err_close--;
			}
		}
		return -1;
	}
	if(stat(src, &st)) {
		err_data = src;
		err_close = 1;
		err_func = "stat";
		goto error;
	}
	if((fdd = open(dst, O_WRONLY | O_CREAT | O_TRUNC, st.st_mode)) == -1) {
		err_data = dst;
		err_close = 1;
		err_func = "open";
		goto error;
	}

	while(done < (uint64_t) st.st_size) {
		ssize_t nread = read(fds, buf, sizeof buf);
		if(nread == -1) {
			err_data = src;
			err_func = "read";
			err_close = 2;
			goto error;
		} else if (nread == 0)
			break;
		else {
			ssize_t nwrote = 0, nwrote_s;

			if(fdd != -1) while(nwrote < nread) {
				nwrote_s = write(fdd, buf + nwrote, nread - nwrote);
				if(nwrote_s == -1) {
					err_data = dst;
					err_close = 2;
					err_func = "write";
					goto error;
				}
				nwrote += nwrote_s;
			}
			done += nread;
		}
	}
	close(fds);
	if (fdd != -1) close(fdd);
	return 0;
}

static int copylink(char* src, char* dst) {
	char buf[512];
	ssize_t ret;

	ret = readlink(src, buf, sizeof(buf) - 1);
	if(ret == -1) return -1;
	buf[ret] = 0;

	return symlink(buf, dst);
}

static int copydir(char *src, char *dst) {
	int ret = 0;
	if(!isdir(dst) && makedir(dst)) {
		errorp("mkdir", "%s", dst);
		return 1;
	}
	DIR *dir = opendir(src);
	struct dirent *ent;
	while((ent = readdir(dir))) {
		char *ibas = ent->d_name;
		if(ent->d_type == DT_DIR && ibas[0] == '.' &&
		   (!ibas[1] || (ibas[1] == '.' && !ibas[2])))
			continue;
		char sfull[512], target[512];
		snprintf(sfull, sizeof sfull, "%s/%s", src, ibas);
		snprintf(target, sizeof target, "%s/%s", dst, ibas);
		if(ent->d_type == DT_DIR)
			ret |= copydir(sfull, target);
		else if(ent->d_type == DT_LNK || ent->d_type == DT_REG) {
			if(verbose) fprintf(stdout, "copying %s -> %s\n", sfull, target);
			if(overwrite_on_copy || !fileexists(target)) {
				if(ent->d_type == DT_LNK)
					ret |= copylink(sfull, target);
				else
					ret |= copyfile(sfull, target);
			}
		} else {
			if(verbose) fprintf(stderr, "ignoring unknown file %s\n", target);
		}
	}
	closedir(dir);
	return ret;
}

static char* path_comp(char *path, int x, char* work) {
	char* p = path, *q;
	int c = 0;
	do {
		++p;
		if(c++ == x) break;
	} while ((p = strchr(p, '/')));
	assert(p);
	strcpy(work, p);
	if((q = strchr(work, '/'))) *q = 0;
	return work;
}

static int path_count(char* path) {
	int c = 0;
	while(*path)
		if(*(path++) == '/') {
			++c;
			while(*path == '/')++path;
		}
	return c;
}

static int linktree_i(char *srcp, char *dstp, int docopy) {
	char *src, *dst, work1[512], work2[512];
	if(!(src = realpath(srcp, NULL))) return 1;
	if(!(dst = realpath(dstp, NULL))) {
		fprintf(stderr,
			"warning: creating base directory %s\n"
			"this directory is supposed to exist already.\n"
			"fix its permissions after this task.\n"
			, dstp);
		if(makedir(dstp)) {
			errorp("mkdir", "%s", dstp);
			return 1;
		}
		if(!(dst = realpath(dstp, NULL)))
			return 1;
	}
	if(docopy) {
		return copydir(src, dst);
	}
	int cnt_src = path_count(src);
	int cnt_dst = path_count(dst);
	int n;
	if(cnt_src > cnt_dst) n = cnt_dst;
	else n = cnt_src;
	int i;
	for(i=0; i<n; ++i) {
		if(strcmp(path_comp(src, i, work1), path_comp(dst, i, work2)))
			break;
	}
	int ncommon = i;
	char back_src[512];
	back_src[0] = 0;
	while(i < cnt_dst) {
		if(!back_src[0]) strcat(back_src, "..");
		else strcat(back_src, "/..");
		++i;
	}
	i = ncommon;
	while(i < cnt_src -1) {
		strcat(back_src, "/");
		strcat(back_src, path_comp(src, i, work1));
		++i;
	}
	return linkdir(src, dst, back_src);
}
static int linktree(char *src, char *dst) {
	return linktree_i(src, dst, 0);
}
static int copytree(char *src, char *dst) {
	return linktree_i(src, dst, 1);
}

static int usage(void) {
	fprintf(stderr,
	"usage: butch-relocate-c pkg1 [...pkgN]\n"
	"tool to symlink a built package from %s/pkgname to the fs root.\n"
	"error: at least one package name is required.\n"
	, staging_dir);
	return 1;
}

int main(int argc, char**argv) {
	staging_dir = getenv("butch_staging_dir");
	if(!staging_dir) staging_dir = "/opt";
	overwrite_on_copy = getenv("butch_do_overwrite_on_copy") ?
		atoi(getenv("butch_do_overwrite_on_copy")) : 0;
	R = getenv("R");
	if(!R) R="";
	if(R[0] == '/' && !R[1]) R="";
	prefix = getenv("butch_prefix");
	if(!prefix) prefix="";
	if(getenv("V")) verbose = 1;
	if(argc < 2) return usage();
	int ec = 0, i, loc;
	for(i = 1; i < argc; ++i) {
		char install_dir[512];
		snprintf(install_dir, sizeof install_dir, "%s%s/%s",
			R, staging_dir, argv[i]);
		if(!isdir(install_dir)) {
			fprintf(stderr, "i: %s\n", install_dir);
			fprintf(stderr, "warning: package %s does not seem to be installed\n", argv[i]);
			ec = 1;
			continue;
		}
		static const char* locs[] = {"bin", "sbin", "include", "lib", "libexec", "share"};
		char source_dir[512], dest_dir[512];

		for(loc = 0; loc < ARRAY_SIZE(locs); ++loc) {
			snprintf(source_dir, sizeof source_dir, "%s%s/%s",
				install_dir, prefix, locs[loc]);
			if(!isdir(source_dir)) continue;

			snprintf(dest_dir, sizeof dest_dir, "%s%s/%s",
				R, prefix, locs[loc]);
			ec |= linktree(source_dir, dest_dir);
		}
		static const char* clocs[] = {"etc", "var", "boot"};
		for(loc = 0; loc < ARRAY_SIZE(clocs); ++loc) {
			/* no butch_prefix here because these are always in / */
			snprintf(source_dir, sizeof source_dir, "%s/%s",
				install_dir, clocs[loc]);
			if(!isdir(source_dir)) continue;
			snprintf(dest_dir, sizeof dest_dir, "%s/%s",
				R, clocs[loc]);

			int ow_safe = overwrite_on_copy;
			if(loc == 2) /* boot */
				overwrite_on_copy = 1;

			ec |= copytree(source_dir, dest_dir);
			overwrite_on_copy = ow_safe;
		}
	}
	return ec;
}
