--- a/deps/openssl/openssl/crypto/ui/ui_openssl.c
+++ b/deps/openssl/openssl/crypto/ui/ui_openssl.c
@@ -46,6 +46,7 @@
 #  if defined(_POSIX_VERSION) && _POSIX_VERSION>=199309L
 
 #   define SIGACTION
+#   undef TERMIO
 #   if !defined(TERMIOS) && !defined(TERMIO) && !defined(SGTTY)
 #    define TERMIOS
 #   endif
