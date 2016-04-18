--- node-v0.10.2.org/deps/openssl/openssl/crypto/ui/ui_openssl.c	2013-04-01 22:15:33.447000003 +0000
+++ node-v0.10.2/deps/openssl/openssl/crypto/ui/ui_openssl.c	2013-04-01 22:40:28.785000003 +0000
@@ -147,6 +147,7 @@
 # if defined(_POSIX_VERSION)
 
 #  define SIGACTION
+#  undef TERMIO
 #  if !defined(TERMIOS) && !defined(TERMIO) && !defined(SGTTY)
 #   define TERMIOS
 #  endif
