# The Saboteur's Cookbook

A guide to running Sabotage for the experienced Linux user.

### Butch, the build manager

`butch` is a collection of shell-scripts wrapping around a 700 LOC C
program written from scratch named `butch-core`.

It handles package downloads, checksums, builds and dependencies in a
relatively sane manner.

It supports the following commands:

	install [<package> ... ]  # build and install <packages>
	download [<package> ... ] # download tarballs required by <packages>
	rebuild [<package> ... ]  # rebuild already installed <packages>

	relink <package>          # create symlinks for an unlinked <package>
	unlink <package>          # remove symlinks to a specific <package>
	genfilelist <package>     # create filelist for <package>

	pack [--method] <package> # create a binary archive of <package>
	unpack <filename>         # install binary archive <filename> created with pack
	builddeps <package>       # build and install dependencies of package

	list                      # list installed packages
	files <package>           # show files installed by <package>
	mirrors <package>         # print mirrors for <package>
	owner <file>              # print which package owns a <file>
	users <package>           # print packages with <package> for dependency

	checksum <package>        # print checksums of files for a <package>
	checkdownloads            # verify all package download links
	checktarballs             # verify the downloaded package tarballs

	printsec <pkg> <section>  # print the specified <section> of <package>
	search <term>             # search for <term> in packages (grep syntax)

	dlinfo <url>              # download url, print initial butch recipe

	update                    # rebuild installed packages with new recipes

`butch` will start up to sixteen download threads and up to two build threads. 

By default, `butch` uses the system's `wget`. To enable HTTPS support install 
the `stage2` package, which adds `libressl` and `ca-certificates` to the system.
You may also use `curl` by exporting `USE_CURL=1`. For best results, download
all packages before the install process.

`butch` defaults to installing built packages into `/opt/$packagename`. Files
are then symlinked into a user-definable path, defaulting to `/`. Finally, the
package name and hash of its recipe are then written to `/var/lib/butch.db`.

The `/opt` path can be overridden by adding the variable `butch_staging_dir` to
the config file and setting it to the desired value. It must consist of a single
component, for example `/foo` `/app` or `/Packages`. The staging dir will
always be used inside the filesystem root specified in the used config.

`butch` may also be used for system configuration, eschewing the package
building features by simply calling `exit 0` at the conclusion of a package
recipe. This will avoid the above package installation procedure.

To completely remove a package:

	$ rm -rf /opt/$pkg
	$ butch unlink $pkg
	$ sed -i '/$pkg/d' /var/lib/butch.db # ... or edit by hand.


### /src, the heart of the system

`/src` is the default path where `butch` searches for and builds packages.

	/src
	/src/pkg        # package recipes, used by butch
	/src/KEEP       # patches and other files referenced from scripts
	/src/build      # package build directory. Safe to empty from time to time
	/src/filelists  # per-package file lists, referenced by `butch unlink`
	/src/logs       # per-package download and build logs
	/src/tarballs   # upstream package tarballs
	/src/utils      # sabotage utilities and helper scripts

`butch` requires `/src/pkg`,`/src/KEEP` and `/src/config`. It will fail to
start if they are missing. The rest of this directory is optional with caveats.

Erasing `/src/filelists` will break `butch unlink <package>` for existing
packages.

`find . -type f -or -type l > /src/filelists/$packagename.txt` from
the installation directory recovers the list.

Erasing `/src/utils` will lose scripts for cross-compilation, writing recipes,
managing chroots and other functionality. Each script contains brief
documentation explaining usage. 

There is no issue erasing `/src/tarballs`, `/src/logs` or `/src/build` beyond
the obvious. 

It is suggested to clone the upstream repo as `/src/sabotage`:

	$ git clone git://github.com/sabotage-linux/sabotage /src/sabotage
	$ rm -rf /src/KEEP /src/pkg
	$ ln -sf /src/sabotage/KEEP /src/KEEP
	$ ln -sf /src/sabotage/pkg /src/pkg

You can issue a `git pull` in `/src/sabotage` to update to the latest version of
recipes and utilities.


### Writing recipes


	[mirrors]
	[vars]
	[deps]
	[build]

`butch` recipes are plain text files that contain one or more labeled headers
and their associated data. The above four sections are central to an assortment
of different possible recipes. This section details their use. 

	[mirrors]
	<url #1>
	...
	<url #n>

	[vars]
	filesize=<bytes>
	sha512=<sha 512 hash>
	tardir=<directory name the tar extracts to, if it differs from the tar name>
	tarball=<optionally specified, if needed>

`[mirrors]` and `[vars]` are optional, but must be included together as a set.
HTTP(S) is the only valid protocol for `[mirrors]`. `tardir` and `tarball` are
optional directives and are usually omitted.

The `[vars]` section is copied verbatim to the top of these generated scripts and
may contain shell code.

The `utils/dlinfo` script is useful in generating the above sections for you.

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

Any combination of the above three headers may optionally be present.

`[deps]` is the standard list of dependencies required by the recipe.
`[deps.host]` are dependencies required on the host for cross-compilation.
`[deps.run]` are requirements to run the package on the target system.

	[build]
	<shell instructions to build application>

Shell instructions inside [build] will be performed by butch during
installation. Specifying `butch_do_relocate=false` inside `[build]` will
prevent the post-build linking of files. If the`[build]` phase calls `exit`,
`butch` will not perform any post-build activities at all.

These recipe elements combine with `KEEP/butch_download_template.txt` as a
`build/dl_package.sh` script. They also join 
`KEEP/butch_template_configure_cached.txt` to form `build/build_package.sh`.

Metapackages containing only a `[mirrors]` & `[vars]`, `[deps]` or `[build]`
section are useful.


### Variables and Templates

Sabotage provides environment variables used for scripts and recipes, sourced
from `/src/config`. This section describes them in detail.

The `stage1` values are provided here, along with a brief description of the variable.

        SABOTAGE_BUILDDIR="/tmp/sabotage"

Defines where the `./build-stage0` script builds a chroot.
	
	A=x86_64

Selects an architecture to build for. 'i386', 'arm', 'mips' and 'powerpc' are
other options.

	CC=gcc
	HOSTCC=gcc

The C compiler used. `gcc` is currently the only compiler tested and supported.
	
	MAKE_THREADS=1

The number of threads to pass to make via the -j flag.

        BUTCH_BIN="/a/path/to/butch-core"

If not set, `./build-stage0` will download and build `butch`. On systems lacking a
proper libc, you may need to statically build `butch` yourself then specify it with
this variable.

	R=/               # `R` is the system root that butch will link packages into
	S=/src            # `S` is the source directory for `butch`
	K=/src/KEEP       # `K` is a directory of needed files and patches
	C=/src/tarballs   # `C` is the downloaded tarball cache
	LOGPATH=/src/logs # `LOGPATH` is where everything is logged

Internal paths, useful when writing scripts and recipes. You should leave these
all as-is, this is the intended way. 

	BUTCH_BUILD_TEMPLATE="$K"/butch_template_configure_cached.txt

The build template. It creates packages in `$R/opt/$package_name` and
optionally supplies a `config.cache` file to speed up some from-source
compilation recipes. Review the template to see its configurable options.
	
	BUTCH_DOWNLOAD_TEMPLATE="$K"/butch_download_template.txt

The download template. It downloads, tests and unpacks tarballs.

        STAGE=1

Used during the bootstrap process by scripts to determine the current stage.
Leave this alone.


### Installing the system

See the wiki page "Bootstrap to HD Image" or `utils/write-hd-image`.


### Encrypted file systems

Install the `cryptsetup` package, then follow this guide to setup your partitions:

http://wiki.centos.org/HowTos/EncryptedFilesystem

Add appropriate entries in `/etc/crypttab` and `/etc/fstab`.
On startup, Sabotage's `rc.boot` will mount them.


## System Administration

Sabotage does things a bit differently than your usual Linux distribution!


### The file system

Sabotage does not follow the Filesystem Hierarchy Standard.  

For legacy support, `/usr` is a symlink to `/` and `/sbin` is a symlink to
`/bin`.
Install software with `--prefix=/` when possible.
The times of a separate root partition are long over. 

`/local` is provided to users, use it wisely.
 Software not packaged by Sabotage should not touch stuff outside of `/local`,
it could break on updates.

Use `/srv/$SERVICE/$VHOST` for all server data.


### The init system

Sabotage uses `runit` as init system, though we use Busybox init to start
`runsvdir`.
See: http://busybox.net/~vda/init_vs_runsv.html

The base system has a few services:

* dmesg - logs kernel messages
* sshd  - opensshd, down by default
* tty2, tty3, tty4 - three gettys
* crond - cron daemon

You will find these in `/var/service`, which are symlinks to `/etc/service`.

You can start services with `sv u $SERVICE` or take them down with
`sv d $SERVICE`.
By default, all services in `/var/service` start at boot time.
If they have an empty `down` file in their directory, you'll have to start them
manually.
If you don't want to use a service at all, best remove the symlink to
`/etc/service`.

Find out what's running with `sv s /var/service/*`.

Look into the service directories to find out how to add your own services.
Note that you must tell them not to daemonize!

For the rest of `runit`, refer to the documentation at:

	http://smarden.org/runit/index.html


### Logging

There is no syslog support, services should use `svlogd` to log into `/var/log`. 

To use `svlogd` ensure your service script dumps the service's output to
stdout/stderr.

Examples: `/etc/service/crond/run` and `/etc/service/dmesg/run`

You can inspect the logs by looking at `/var/log/$SERVICE/current`. 

For example, kernel messages are in `/var/log/dmesg/current`.

You can look at all logs with `sort /var/log/*/current |less`.

For more information, see `runit` docs. 

### Transfering packages

Packages can be transfered and installed on another system than the one they
were built on. basically it's sufficient to copy the build host's directory
`/opt/packagename` to the target's `/opt`, (use cp -a to preserve symlinks) and
then call `butch relink packagename` on the target.
An entry should be added to `/var/lib/butch.db`, so butch knows that it's
already installed (the sha512sum can be copied from another package's entry).
The commands `butch pack packagename` and `butch unpack filename` automate this
task on the build and target host, respectively.


### Other advice

#### Start sshd

* Execute `sv u sshd`.


#### Linux console keyboard layout

* Execute `loadkeys`, then follow the instructions.


#### For X

* Edit `/etc/xinitrc`, or copy it to `~/.xinitrc` and edit that.
  There's a commented line suggesting how to change `setxkbmap` invocation.
* Uncomment and change the two-letter country code to your country.
* Edit `/bin/X` and enable QEMU or VirtualBox settings, if needed, otherwise
  your controls won't work!
* Execute `startx`.


#### Using a WLAN

* Install `wpa-supplicant`.
* Edit `/etc/wpa_supplicant.conf` for WiFi config.
* Edit `/etc/wpa_connect_action.sh` for IP address settings.
* Execute `sv u wpa_supplicant`.
* To keep the service up permanently, execute
  `rm /etc/service/wpa_supplicant/down`.


#### Getting a DHCP IP address

* Execute `dhclient eth0`.


#### Setting a static IP address

* Execute `ifconfig eth0 192.168.0.2 netmask 255.255.255.0`.
* Execute `route add default gw 192.168.0.1`.

You can put the above into a script which `/etc/rc.local` can execute at boot
time. 


#### Wine 

Wine builds on Sabotage i386.
To use it on x86_64, one needs to use packages built on i386 Sabotage.

For example, the following 32-bit packages are required to run simple Delphi
programs:

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

You can get them off `/opt` from a Sabotage i386 image or rootfs.
From `musl` we need `libc.so`.
We also need everything from the `wine` package and the `lib/.so` from all
other packages.
Make a directory to put the stuff, we use `/32bit` here.

	$ mkdir -p /32bit/lib
	$ mv musl-i386/lib/libc.so /32bit/lib
	$ ln -sf /32bit/lib/libc.so /lib/ld-musl-i386.so.1
	$ echo "/32bit/lib:/32bit/wine/lib" > /etc/ld-musl-i386.path
	$ cd /32bit
	$ tar xf wine.i386.tar.xz
	$ for p in `cat 32bit-packages.txt`; do tar xf "$p".i386.tar.xz; mv "$p"/lib/* lib/; rm -rf lib/pkgconfig; done
	$ rm lib/*.a

Now it should be possible to use `/32bit/wine/bin/wine` to execute Windows
programs.
Here`s a pre-made package that includes the work from the above steps:

	http://mirror.wzff.de/sabotage/bin/wine-i386-bundle.tar.xz

	sha512sum: 2475ac72f62a7d611ab1ca14a6a58428bd07339f81e384bf1bbbd0187b2467c371f79fee9d028149eebd3c6a80999e5676364d1bc8054022f89de8cc66169b84

You only need to create the `ld-musl-i386.so` symlink and the entry in
`/etc/ld-musl-i386.path`


#### Timezones

The `timezones` package installs timezone description files into
`/share/zoneinfo`.
`musl` supports timezones via the POSIX `TZ` environment variable.
You should set it in your `~/.profile` or in `/etc/profile`.
`glibc` also supports `/etc/localtime`, which is a copy or symlink of one of 
the zoneinfo files. 

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

When `rc.boot` executes, the system clock is set to the hardware clock using
`hwclock -u -s`, where `-u` stands for UTC.
`hwclock -u -r` can read the actual hardware clock, adjusted to the users' `TZ`.
If you want to see the actual UTC clock value, set `TZ=UTC` and then
`hwclock -u -r`.

if your hardware clock is off, you can fix it by using
`ntpd -dnq -p pool.ntp.org` to get the actual time, then write it to BIOS using
`hwclock -u -w`.

