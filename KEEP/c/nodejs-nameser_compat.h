--- node-v0.10.2.org/deps/cares/config/linux/ares_config.h	2013-04-01 22:15:33.584000003 +0000
+++ node-v0.10.2/deps/cares/config/linux/ares_config.h	2013-04-01 22:17:06.144000004 +0000
@@ -53,7 +53,7 @@
 #define HAVE_ARPA_INET_H 1
 
 /* Define to 1 if you have the <arpa/nameser_compat.h> header file. */
-#define HAVE_ARPA_NAMESER_COMPAT_H 1
+/* undef HAVE_ARPA_NAMESER_COMPAT_H */
 
 /* Define to 1 if you have the <arpa/nameser.h> header file. */
 #define HAVE_ARPA_NAMESER_H 1
