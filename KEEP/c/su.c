/* (C) 2013 rofl0r, based on design ideas of Rich Felker.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/

#define _BSD_SOURCE
#include <unistd.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <crypt.h>
#include <string.h>
#include <grp.h>
#include <fcntl.h>
#include <time.h>
#include <sys/stat.h>

#if 1 || defined(IN_KDEVELOP_PARSER)
#define HAVE_SHADOW
#endif
#ifdef HAVE_SHADOW
#include <shadow.h>
#else
#warning "shadow support disabled, did you forget to pass -DHAVE_SHADOW ?"
#endif

#if !defined(_Noreturn) && __STDC_VERSION__+0 < 201112L
#ifdef __GNUC__
#define _Noreturn __attribute__((noreturn))
#else
#define _Noreturn
#endif
#endif

static const char usage_text[] =
"Usage: su [OPTION] name\n"
"available options:\n"
"- : start login shell\n"
"-c command : run command and return\n"
"-s shell   : use shell provided as argument (root only)\n"
"if name is omitted, root is assumed.\n";

static _Noreturn void usage(void) {
	dprintf(1, usage_text);
	exit(1);
}

static _Noreturn void perror_exit(const char* msg) {
	perror(msg);
	exit(1);
}

static int directory_exists(const char* dir) {
	struct stat st;
	return stat(dir, &st) == 0 && S_ISDIR(st.st_mode);
}

static time_t get_mtime(const char *fn) {
	struct stat st;
	if(stat(fn, &st)) return -1;
	return st.st_mtime;
}

static void touch(const char* fn) {
	int fd = open(fn, O_RDWR | O_CREAT | O_TRUNC, 0600);
	if(fd != -1) close(fd);
}

/* returns index of username argument, 0 if no username passed, -1 on syntax error
 * cmd_index will be set to the index of a -c argument, or 0 if its missing
 * shell_index will be set to the index of a -s argument, or 0 if its missing
 * login_shell will be set to 1 if the login shell option - was passed, 0 otherwise */
static int parse_args(int argc, char** argv,
	             int *login_shell, int* cmd_index, int *shell_index) {

	*login_shell = 0;
	*cmd_index   = 0;
	*shell_index = 0;

	int i, wantarg = 0, res = 0;
	char *p;

	for(i = 1; i < argc; i++) {
		if(wantarg) {
			wantarg = 0;
			continue;
		}
		p = argv[i];
		if(p[0] != '-') {
			if(res) return -1;
			res = i;
		} else if(!p[1]) {
			*login_shell = 1;
		} else if((p[1] == 'c' || p[1] == 's') && !p[2]) {
			if(i == argc - 1) return -1;
			wantarg = 1;
			if(p[1] == 'c') *cmd_index = i + 1;
			else *shell_index = i + 1;
		} else {
			return -1;
		}
	}
	if(wantarg) return -1;
	return res;
}

/* return 1 if the password check succeeded, 0 otherwise */
int check_pass(const char* name, const char *pass, struct passwd *pwd) {
        const char *encpw;
#ifdef HAVE_SHADOW
	struct spwd *shpwd = getspnam(name);
	if(!shpwd) return 0;
	encpw = shpwd->sp_pwdp;
#else
	(void) name;
	encpw = pwd->pw_passwd;
#endif
	if(!encpw || !strcmp(encpw, "x")) return 0;
	const char* actpw = crypt(pass, encpw);
	if(!actpw) perror_exit("crypt");
	if(strcmp(actpw, encpw)) return 0;
	return 1;
}

extern char** environ;

#define SU_DIR "/var/lib/su"
#define LOGIN_DELAY_SECS 1
#define STRIFY2(x) #x
#define STRIFY(x) STRIFY2(x)
#define LOGIN_DELAY_SECS_STR STRIFY(LOGIN_DELAY_SECS)

int main(int argc, char** argv) {
	int login_shell, cmd_index, shell_index, name_index;
	name_index = parse_args(argc, argv, &login_shell, &cmd_index, &shell_index);
	if(name_index == -1) usage();

	int uid = getuid();
	int is_root = (uid == 0);
	if(shell_index && !is_root) usage();

	const char* name = name_index ? argv[name_index] : "root";

	char uidfn[256];
	snprintf(uidfn, sizeof uidfn, "%s/%d", SU_DIR, uid);

	if(!directory_exists(SU_DIR)) {
		if(geteuid() == 0 && mkdir(SU_DIR, 0700) == -1)
			dprintf(2, "creation of directory " SU_DIR
			           " for bruteforce prevention failed, consider creating it manually\n");
	}

	char* pass = 0;

	if(!is_root) {
		time_t mtime = get_mtime(uidfn);
		if(mtime != -1 && mtime + LOGIN_DELAY_SECS > time(0)) {
			dprintf(2, "you need to wait for " LOGIN_DELAY_SECS_STR
			           " seconds before retrying.\n");
			return 1;
		}
		pass = getpass("enter password:");
		dprintf(1, "\n");
		if(!pass) perror_exit("getpass");
	}

	struct passwd *pwd = getpwnam(name);
	if(!pwd) goto failed;
	if(!is_root && !check_pass(name, pass, pwd)) {
		failed:
                touch(uidfn);
                dprintf(2, "login failed\n");
		return 1;
	}

	if(initgroups(name, pwd->pw_gid)) perror_exit("initgroups");
	if(setgid(pwd->pw_gid)) perror_exit("setgid");
	if(setuid(pwd->pw_uid)) perror_exit("setuid");

	char* const* new_argv;
	char shellbuf[256];
	char* shell = shell_index ? argv[shell_index] : pwd->pw_shell;
	char* shell_argv0 = shell;
	if(login_shell) {
		snprintf(shellbuf, sizeof shellbuf, "-%s", shell);
		shell_argv0 = shellbuf;
		setenv("LOGNAME", name, 1);
		if(getenv("USER")) setenv("USER", name, 1);
	}
	if(cmd_index) {
		new_argv = (char* const[]) {shell_argv0, argv[cmd_index-1], argv[cmd_index], 0};
	} else {
		new_argv = (char* const[]) {shell_argv0, 0};
	}

	setenv("HOME", pwd->pw_dir, 1);
	if(login_shell) chdir(pwd->pw_dir);

	if(execve(shell, new_argv, environ)) perror_exit("execve");
	return 1;
}
