# Sabotage Linux

This is Sabotage, an experimental distribution based on musl libc and busybox.

Currently Sabotage supports i386, x86_64, MIPS, PowerPC32 and ARM(v4t+).
ARM hardfloat (hf) is supported via crosscompilation of stage1,
since it requires a recent GCC which we can't easily bootstrap in stage0 due
to library dependencies of GCC introduced with 4.3.

The preferred way to build Sabotage is using a native Linux environment for
the desired architecture.
It is now also possible to cross-compile large parts of it.
As cross-compiling is hairy and support for it is quite new, expect breakage.
Native builds are well tested and considered stable.


## Requirements:

* ~4G free disk space.
* A Linux 3.8+ host kernel with USER_NS support, for entering native chroots
  without root.
* A Linux 2.6+ host kernel can be used, but requires root access.
* A `gcc` 4.x tool chain.
* `git`, to check out the repository.
* `bzip2`, `sed`, `patch`, `tar`, `wc`, `wget` and `xz` are needed to run the
  build script.
* Lots of time and a fair bit of Linux knowledge.

This system has built *natively* on Debian 6 & 7, Fedora 18 & 21, Ubuntu 14.04,
Ubuntu 16.04, openSUSE 13.2, Alpine 3.1.2 and Void Linux.


## Obtaining Sabotage

You can bootstrap your own build from the scripts at:

https://github.com/sabotage-linux/sabotage

Download ready-to-boot QEMU/VirtualBox disk images that you may also extract
the rootfs from:

* DE : http://ftp.barfooze.de/pub/sabotage/
* GR : http://foss.aueb.gr/mirrors/linux/sabotage/
* FR : http://mirrors.2f30.org/sabotage/

The DE mirror is the master from which the other mirrors are periodically
synced.

SHA512 checksums for releases get posted on the mailing lists, archived here:

http://openwall.com/lists/sabotage/

**READ THE COOKBOOK FIRST BEFORE POSTING**.


## Native Build Instructions:

**DO NOT RUN SCRIPTS YOU HAVE NOT READ**.

	$ cp KEEP/config.stage0 config
	$ vi config

Set the `SABOTAGE_BUILDDIR`, `A`, and `MAKE_THREADS` variables.
You may usually ignore the other values.
Both the config file and the COOKBOOK cover the meaning of these variables.

NOTE: It is possible to build an i386 Sabotage from within an existing 32-bit
chroot on a 64-bit system.
The `enter-chroot` script automatically handles this scenario.

	$ ./build-stage0        # ~2min on 3GHz 8core, 75min on ARM A8 800Mhz
	$ ./enter-chroot

Once inside the chroot:

	$ srcprep --stage1       # Installs core system + build chain

The `srcprep --stage1` script installs the remaining packages, then rebuilds
the entirety of stage1 again. This rebuild not only removes all traces of the
bootstrap and produces better binaries, but the resulting packages should
be identical to ones produced on different systems. Finally, all unneeded
bootstrap packages are removed.

You may instead execute `butch install stage1`, which will skip the rebuild and
removal of the bootstrap packages. Later you can execute `srcprep --stage1`
to finish the procedure.

At this point, stage1 is complete and your Sabotage chroot is set up. You may
now install optional packages:

	$ butch install core    # networking + base developer system
	$ butch install desktop # everything needed for X11 + audio + core

At this point, you will need to select the window manager and other provided
applications. You may use `butch install gui` for a lightweight preset, but
you are encouraged to make your own that build off of either `desktop` or
`core`.

Get a list available packages by using `ls /src/pkg`.

At any time, you may add the default kernel:

	$ butch install kernel

Run `butch` and look at the usage information for further options.

`butch` uses build templates that allow for a high level of customization.
`KEEP/butch_build_template.txt` is the base template used by Sabotage.
It provides a tuned `config.cache` for faster configure runs.
It also installs packages into `/opt`, creates file lists, etc.


## After Compiling

Exit the chroot and either:

* Run `utils/root-perms.sh /path/to/rootfs` to fix permissions
* Use the rootfs directly, by copying it to some disk.
* Use `utils/run-emulator.sh` to boot the system in QEMU.
  Running in QEMU has poor HDD performance, as the FS is mounted via 9P protocol.
  It's not recommended for building packages, but it's practical for testing.
* Use `utils/write-hd-image.sh` to create an image file.
  The image file boots in QEMU.
  To convert it into VirtualBox format use `VBoxManage convertfromraw`.


## RUNNING SABOTAGE FOR THE FIRST TIME

The default root password is "sabotage".

Start the sshd service using `sv u sshd`, which will create keys on first use.
To make the service autostart on boot, remove `/etc/service/sshd/down`.

Edit `/etc/rc.local` for other things to autostart, such as network
configuration, DHCP, console keymapping...

If you have X installed, edit the example `/bin/X` for the correct evdev
settings, then run `startx`.
Check `/etc/xinitrc` for X11 keyboard configuration.


## Cross-Compile Requirements:

* [musl-cross][0] or [musl-cross-make][1] for your target arch.
* `butch` installed for the build host in $PATH
   (since it lives in KEEP/bin, adding that to $PATH will also do).
* `pkgconf` symlinked as pkg-config in $PATH, before other pkg-config versions.
  a standard `pkg-config` installed on the host may also work, but is untested.
* Packages may have a `deps.host` section listing further packages required on
  the host.

The only supported cross-compile setup is using a Sabotage host that has the
same packages installed as the ones you wish to compile, but it was also
successfully used on non-sabotage hosts.

If you intend to cross-compile only packages written in C, the choice of the
version of your cross-compiler is not important. If you however intend to
compile also C++ packages, you should use the same GCC version that is built
as default during stage1 (currently GCC 6.5.0) from `musl-cross-make` repo.
that is necessary so the applications are built against the same libstdc++
they'll be bundled together with (if they use dynamic linking).

additionally, the cross toolchain needs to use the identical (currently 2.27)
or an older binutils version as in our `binutils` package.
newer binutils often immediately default to new features that the older versions
can't deal with (e.g. https://github.com/richfelker/musl-cross-make/pull/73 )


## Cross-Compile Instructions:

	$ mkdir x-prefix/powerpc
	$ cd x-prefix/powerpc
	$ cp SABOTAGEDIR/KEEP/config.cross config
	$ vi config # set your vars
	$ CONFIG=./config SABOTAGEDIR/utils/setup-rootfs.sh # initialize rootfs
	$ CONFIG=./config butch install nano # start building stuff

Much like a native build, a config file is copied and edited.
`utils/setup-rootfs.sh` is run instead of `./build-stage0` to construct the
new root.
Finally, we use `butch` to start cross-compiling and installing packages into
it.
Unlike native compilation, you don't have to build any stages, you can
immediately start compiling the packages you're interested in. If you intend
to use the resulting rootfs to boot into, you should however start with building
`stage1`, and if you want to use the resulting rootfs as a full sabotage
installation with development tools, also the package `base-dev`.

Note that you need to build the `make` and `binutils` packages additional to
`stage1` if you intend to use the resulting rootfs with full compiler toolchain.


## NOTES TO CONTRIBUTORS

Please use unified `diff` format (`diff -u`) for patches.

### Use Git

It is necessary that you create `git` branches for your work.
This allows your changes to be checked out and rebased as needed, without merge
conflicts.

Do not commit more than one change/package in a single commit.
Use a meaningful commit message that mentions the package name.
Please follow the style and conventions of your fellow contributors.

### Use Templates

When creating packages, try starting from the autoconf template:

	$ cp KEEP/pkg_skel/autoconf pkg/my-new-pkg

There are other convenient templates located in `KEEP/pkg_skel/` as well.

Try running `utils/dlinfo.sh`:

	$ utils/dlinfo.sh http://1.2.3.4/my_new_pkg.tar.xz

`utils/dlinfo.sh` will return the file stats and sha512sum for easy copying
and pasting into your new package.

### Package Name Guideline

Package names may consist of the following characters: a-z 0-9 -
i.e: lower-case and numbers only, dash to separate.

Perl5 modules from cpan must be named as perl5-Module-Submodule,
for examples perl5-XML-Parser. Uppercase should be applied exactly
as in the module name.

Python modules must be named as python-module.
example: python-setuptools

Following this convention makes it possible to use package names in
regexes or URLs without having to escape or encode/decode them.

### Package Sources and Philosophy

Sabotage is designed with limited internet availability in mind.
After downloading packages in advance, when you have internet, you may build
later offline at your leisure.

Space considerations are a top issue, both bandwidth and HD image size.
Sabotage ISOs and images ship with all tarballs to fulfill the GPL.
ALWAYS USE a TAR.XZ (preferred) or TAR.BZ2 download URL.

Please do not use FTP mirrors. FTP is a broken, ancient protocol.

Downloads from git or other source repositories are not desired.
This would add an internet connection as a build-time dependency.

### Package maintainance

Even though the sabotage linux team is at the moment rather small, we try to
keep all packages up-to-date, if possible. Updating a package usually requires
at least one test build, and eventually one or more fixes and another rebuild
for each fix. So under some circumstances, this might require several hours of
work. Since our time is limited, some non-core packages that lack a maintainer
and we consider of low importance will be updated (upstream URL) without a build
test and marked as `[untested]` in the commit message.
Those packages may or may not build. If you find a build error in such a package
feel free to report the error or even better, fix it, make a PR and claim
maintainership.


## CONTACT

/join #sabotage on irc.freenode.net for real time help.

**READ THIS DOCUMENT AND THE COOKBOOK FIRST BEFORE ASKING FOR HELP**


## DONATIONS

Bitcoins are welcome:

1HXhSKSyBUGAAga29WbpTkKGpruQq9J8Bb

[0]:https://github.com/GregorR/musl-cross
[1]:https://github.com/richfelker/musl-cross-make
