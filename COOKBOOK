# The Saboteur's Cookbook

A guide to running Sabotage for the experienced Linux user.


## Introduction

### Butch, the build manager

`butch` is a 700 LOC C program written from scratch. It handles package downloads, checksums, builds and dependencies in a relatively sane manner. 

It supports the following commands:

	$ butch install [<package> ... ]  # build and install <packages>
	$ butch prefetch [<package> ... ] # download tarballs required by <packages>
	$ butch rebuild [<package> ... ]  # rebuild already installed <packages>

	$ butch relink <package>          # create symlinks for an unlinked <package>
	$ butch unlink <package>          # remove symlinks to a specific <package>

	$ butch list                      # list all installed packages  
	$ butch files <package>           # show all files installed by <package>
	$ butch owner <file>              # shows which package owns a <file>

	$ butch print <package>           # pretty-print the specified <package>
	$ butch search <term>             # search for <term> in package names (grep syntax)
                 
	$ butch update                    # rebuild packages whose hash differs from butch.db's hash

`butch` will start up to sixteen download threads and up to two build threads. 

By default, `butch` uses busybox's `wget`. This admittedly has some reliability issues and furthermore does not support HTTPS. For best results, prefetch all packages before the build process. If installed, GNU `wget` will work as a replacement. You may also install and use `curl` by exporting `USE_CURL=1`. Both of these alternatives support HTTPS. 

`butch` defaults to installing packages into `/opt/$packagename`. Files are then symlinked into a user-definable path, defaulting to `/`. Finally, the package name and hash of its recipe are then written to `/var/lib/butch.db`.

To completely remove a package:

	$ rm -rf /opt/$pkg
	$ butch unlink $pkg
	$ sed -i '/$pkg/d' /var/lib/butch.db # ... or edit by hand.


### /src, the heart of the system

`/src` is the default path where `butch` searches for and builds packages.

	/src
	/src/pkg        # package recipes, used by butch.
	/src/KEEP       # patches and other files referenced from scripts.
	/src/build      # package build directory. Can grow quite large, safe to empty from time to time.
	/src/filelists  # per-package file lists, referenced by `butch unlink`.
	/src/logs       # per-package download and build logs.
	/src/tarballs   # upstream package tarballs.
	/src/utils      # sabotage utilities and helper scripts.

`/src` is not required by Sabotage once it has installed `stage1`.  You may `rm -rf /src` if you no longer need a build manager on the system. 

`butch` requires `/src/pkg`,`/src/KEEP` and `/src/config`. It will fail to start if they are missing. The rest of this directory is optional with caveats.

Erasing `/src/filelists` will break `butch unlink <package>` for existing packages. `find . -type f -or -type l > /src/filelists/$packagename.txt` from the installation directory recovers the list.

Erasing `/src/utils` will lose scripts for cross-compilation, writing recipes, managing chroots and other functionality. Each script contains breif documentation explaining usage. 

There is no issue erasing `/src/tarballs`, `/src/logs` or `/src/build` beyond the obvious. 

It is suggested to clone the upstream repo as `/src`:

	$ mv /src/config ~
	$ rm -rf /src
	$ git clone git://github.com/sabotage-linux/sabotage /src 
	$ mv ~/config /src

You can issue a `git pull` in `/src` to update to the latest version of recipes and utilities.


### Writing recipes

`butch` recipes are plain text files that contain one or more labeled headers and their associated data.

	[mirrors]
	<url #1>
	...
	<url #n>

	[main]
	filesize=<bytes>
	sha512=<sha 512 hash>
	tardir=<directory name the tar extracts to, if it differs from the tar name>

`[mirrors]` and `[main]` are optional, but must be included together as a set. HTTP(S) URLs are the only valid protocol for `[mirrors]`. `tardir` is an optional directive and is usually omitted. These elements combine with `KEEP/butch_download_template.txt` as a `build/dl_package.sh` script. This script then downloads and verifies the tarball. The `utils/dlinfo` script is useful in generating the above sections for you.

	[deps]
	<package #1>
	...
	<package #n>

	[deps.host]
	<package #1>
	...
	<package #n>

	[deps.run]
	<package #1>
	...
	<package #n>

Any or all three of the above headers may be present. `[deps]` is the standard list of dependencies required by the recipe. `[deps.host]` are dependencies required on the host for cross-compilation. `[deps.run]` are requirements for the target cross-compile system.

	[build]
	<shell instructions to build application>

The shell script contents of `[build]` merges with `KEEP/butch_template_configure_cached.txt` into `build/build_package.sh`. The resulting build script then executes. Specifying `butch_do_relocate=false` inside `[build]` will prevent the post-build linking of installed files. If the`[build]` phase calls `exit`, `butch` will not perform any post-build activities.

Metapackages containing only a `[mirrors]` & `[main]`, `[deps]` or `[build]` section are useful.


### Variables and Templates

Sabotage provides a modest collection of environment variables, sourced from `/src/config`. The `stage1` values are provided here, along with a brief description of the variable.

	SABOTAGE_BUILDDIR="/tmp/sabotage"

Defines where the `./build-stage0` script builds a chroot.
	
	A=x86_64

Selects an architecture to build for. 'i386', 'arm', 'mips' and 'powerpc' are other options.

	CC=gcc
	HOSTCC=gcc

The C compiler used. `gcc` is currently the only compiler tested and supported.
	
	MAKE_THREADS=1

The number of threads to pass to make via the -j flag.

	ARM_FLOAT_MODE=softfp

Sets ARM floating point emulation. 'hard' is not currently supported, use 'softfp'.

	ARM_FPU=vfp

Sets ARM FPU type. 'neon' is not currently supported, use 'vfp'.

	BUTCH_BIN="/a/path/to/butch-core"

If not set, `./build-stage0` will download and build `butch`. On systems lacking a proper libc, you may need to statically build `butch` yourself then specify it with this variable. 

	R=/               # `R` is the root. `./build-stage0` and `utils/setup-rootfs.sh` create new systems here.
	S=/src            # `S` is the `butch` directory containing recipes, files and build directories.
	K=/src/KEEP       # `K` is a directory of patches and needed files.
	C=/src/tarballs   # `C` is the downloaded tarball directory.
	LOGPATH=/src/logs # `LOGPATH` is the log directory for builds.
	H="$PWD"          # `H` is `./build-stage0`' calling location, used only during `stage0`.

Internal paths, useful when writing scripts and recipes. You should leave these all as-is, this is the intended way. 

	BUTCH_BUILD_TEMPLATE="$K"/butch_template_configure_cached.txt

The build template. It creates packages in `$R/opt/$package_name`, supplies a `config.cache` and symlinks packages into the root.
	
	BUTCH_DOWNLOAD_TEMPLATE="$K"/butch_download_template.txt

The download template. It downloads, tests and unpacks tarballs needed by `butch`.
	
	STAGE=1

Used during the bootstrap process by scripts to determine the current stage. Leave this alone.


### Installing the system

See the wiki page "Bootstrap to HD Image" or `utils/write-hd-image`.


### Encrypted file systems

Install the `cryptsetup` package, then follow this guide to setup your partitions:

http://wiki.centos.org/HowTos/EncryptedFilesystem

Add appropriate entries in `/etc/crypttab` and `/etc/fstab`. On startup, Sabotage's `rc.boot` will mount them.


## System Administration

Sabotage does things a bit differently than your usual Linux distribution!


### The file system

Sabotage does not follow the Filesystem Hierarchy Standard.  

For legacy support, `/usr` is a symlink to `/` and `/sbin` is a symlink to `/bin`.  Install software with `--prefix=/` when possible. The times of a separate root partition are long over. 

`/local` is provided to users, use it wisely.  Software not packaged by Sabotage should not touch stuff outside of `/local`, it could break on updates.

Use `/srv/$SERVICE/$VHOST` for all server data.


### The init system

Sabotage uses `runit` as init system, though we use Busybox init to start `runsvdir`.  See: http://busybox.net/~vda/init_vs_runsv.html

The base system has a few services:

* dmesg - logs kernel messages
* sshd  - opensshd, down by default
* tty2, tty3, tty4 - three gettys
* crond - cron daemon

You will find these in `/var/service`, which are symlinks to `/etc/service`.

You can start services with `sv u $SERVICE` or take them down with `sv d $SERVICE`.  By default, all services in `/var/service` start at boot time. If they have an empty `down` file in their directory, you'll have to start them manually.  If you don't want to use a service at all, best remove the symlink to `/etc/service`.

Find out what's running with `sv s /var/service/*`.

Look into the service directories to find out how to add your own services. Note that you must tell them not to daemonize!

For the rest of `runit`, refer to the documentation at:

	http://smarden.org/runit/index.html


### Logging

There is no syslog support, services should use `svlogd` to log into `/var/log`. 

To use `svlogd` ensure your service script dumps the service's output to stdout/stderr.

Examples: `/etc/service/crond/run` and `/etc/service/dmesg/run`

You can inspect the logs by looking at `/var/log/$SERVICE/current`. 

For example, kernel messages are in `/var/log/dmesg/current`.

You can look at all logs with `sort /var/log/*/current |less`.

For more information, see `runit` docs. 


### Other advice

#### Start sshd

* Execute `sv u sshd`.


#### Linux console keyboard layout

* Execute `loadkeys`, then follow the instructions.


#### For X

* Edit `/etc/xinitrc`, or copy it to `~/.xinitrc` and edit that. There's a commented line suggesting how to change `setxkbmap` invocation.
* Uncomment and change the two-letter country code to your country.
* Edit `/bin/X` and enable QEMU or VirtualBox settings, if needed, otherwise your controls won't work!
* Execute `startx`.


#### Using a WLAN

* Install `wpa-supplicant`.
* Edit `/etc/wpa_supplicant.conf` for WiFi config.
* Edit `/etc/wpa_connect_action.sh` for IP address settings.
* Execute `sv u wpa_supplicant`.
* To keep the service up permanently, execute `rm /etc/service/wpa_supplicant/down`.


#### Getting a DHCP IP address

* Execute `dhclient eth0`.


#### Setting a static IP address

* Execute `ifconfig eth0 192.168.0.2 netmask 255.255.255.0`.
* Execute `route add default gw 192.168.0.1`.

You can put the above into a script which `/etc/rc.local` can execute at boot time. 


#### Wine 

Wine builds on Sabotage i386. To use it on x86_64, one needs to use packages built on i386 Sabotage. 

For example, the following 32-bit packages are required to run simple Delphi programs:

	wine
	musl
	alsa-lib #for sound support
	freetype
	libpng
	libsm
	libx11
	libxau
	libxcb
	libxext
	libxi
	libxrender
	ncurses
	zlib-dynamic

You can get them off `/opt` from a Sabotage i386 image or rootfs. From `musl` we need `libc.so`. We also need everything from the `wine` package and the `lib/.so` from all other packages. Make a directory to put the stuff, we use `/32bit` here.

	$ mkdir -p /32bit/lib
	$ mv musl-i386/lib/libc.so /32bit/lib
	$ ln -sf /32bit/lib/libc.so /lib/ld-musl-i386.so.1
	$ echo "/32bit/lib:/32bit/wine/lib" > /etc/ld-musl-i386.path
	$ cd /32bit
	$ tar xf wine.i386.tar.xz
	$ for p in `cat 32bit-packages.txt`; do tar xf "$p".i386.tar.xz; mv "$p"/lib/* lib/; rm -rf lib/pkgconfig; done
	$ rm lib/*.a

Now it should be possible to use `/32bit/wine/bin/wine` to execute Windows programs. Here`s a pre-made package that includes the work from the above steps:

	http://mirror.wzff.de/sabotage/bin/wine-i386-bundle.tar.xz

	sha512sum: 2475ac72f62a7d611ab1ca14a6a58428bd07339f81e384bf1bbbd0187b2467c371f79fee9d028149eebd3c6a80999e5676364d1bc8054022f89de8cc66169b84

You only need to create the `ld-musl-i386.so` symlink and the entry in `/etc/ld-musl-i386.path`


#### Timezones

The `timezones` package installs timezone description files into `/share/zoneinfo`. `musl` supports timezones via the POSIX `TZ` environment variable. You should set it in your `~/.profile` or in `/etc/profile`. `glibc` also supports `/etc/localtime`, which is a copy or symlink of one of the zoneinfo files. 

Example values for `TZ`:

	# Reads `/share/zoneinfo/Europe/Berlin` the first time an app calls localtime().
	TZ=Europe/Berlin 
	# Reads `/etc/localtime` the first time an app calls localtime().
	TZ=/etc/localtime
	# Will set the timezone to GMT+2. (POSIX reverses the meaning of +/-)
	TZ=GMT-2
	# Like Europe/Berlin, except it reads no file. 
	# The string is the last "line" from the zoneinfo file.
	TZ="CET-1CEST,M3.5.0,M10.5.0/3" 


#### hwclock and ntp

When `rc.boot` executes, the system clock is set to the hardware clock using `hwclock -u -s`, where `-u` stands for UTC. `hwclock -u -r` can read the actual hardware clock, adjusted to the users' `TZ`. If you want to see the actual UTC clock value, set `TZ=UTC` and then `hwclock -u -r`.

if your hardware clock is off, you can fix it by using `ntpd -dnq -p pool.ntp.org` to get the actual time, then write it to BIOS using `hwclock -u -w`.

