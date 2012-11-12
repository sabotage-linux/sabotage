/* EINA - EFL data type library
 * Copyright (C) 2007-2008 Jorge Luis Zapata Muga
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library;
 * if not, see <http://www.gnu.org/licenses/>.
 */

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#ifdef EFL_HAVE_THREADS
# ifdef _WIN32
#  define WIN32_LEAN_AND_MEAN
#  include <windows.h>
# elif defined (__sun) || defined(__GNU__)
#  include <unistd.h>
# elif defined (__FreeBSD__) || defined (__OpenBSD__) || \
   defined (__NetBSD__) || defined (__DragonFly__) || defined (__MacOSX__) || \
   (defined (__MACH__) && defined (__APPLE__))
#  include <unistd.h>
#  include <sys/param.h>
#  include <sys/sysctl.h>
# elif defined (__linux__) || defined(__GLIBC__)
#  include <sched.h>
# endif
# ifdef EFL_HAVE_POSIX_THREADS
#  include <pthread.h>
# endif

# define TH_MAX 8
#endif

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

#include "eina_cpu.h"

/*============================================================================*
*                                  Local                                     *
*============================================================================*/

/* FIXME this ifdefs should be replaced */
#if defined(__i386__) || defined(__x86_64__)
/* We save ebx and restore it to be PIC compatible */
static inline void _x86_cpuid(int op, int *a, int *b, int *c, int *d)
{
   __asm__ volatile (
#if defined(__x86_64__)
      "pushq %%rbx      \n\t" /* save %ebx */
#else
      "pushl %%ebx      \n\t" /* save %ebx */
#endif
      "cpuid            \n\t"
      "movl %%ebx, %1   \n\t" /* save what cpuid just put in %ebx */
#if defined(__x86_64__)
      "popq %%rbx       \n\t" /* restore the old %ebx */
#else
      "popl %%ebx       \n\t" /* restore the old %ebx */
#endif
      : "=a" (*a), "=r" (*b), "=c" (*c), "=d" (*d)
      : "a" (op)
      : "cc");
}

static
void _x86_simd(Eina_Cpu_Features *features)
{
   int a, b, c, d;

   _x86_cpuid(1, &a, &b, &c, &d);
   /*
    * edx
    * 18 = PN (Processor Number)
    * 19 = CLFlush (Cache Line Flush)
    * 23 = MMX
    * 25 = SSE
    * 26 = SSE2
    * 28 = HTT (Hyper Threading)
    * ecx
    * 0 = SSE3
    */
   if ((d >> 23) & 1)
      *features |= EINA_CPU_MMX;

   if ((d >> 25) & 1)
      *features |= EINA_CPU_SSE;

   if ((d >> 26) & 1)
      *features |= EINA_CPU_SSE2;

   if (c & 1)
      *features |= EINA_CPU_SSE3;
}
#endif

/*============================================================================*
*                                 Global                                     *
*============================================================================*/

/*============================================================================*
*                                   API                                      *
*============================================================================*/

/* FIXME the features checks should be called when this function is called?
 * or make it static by doing eina_cpu_init() and return a local var
 */
/**
 *
 * @return
 */
EAPI Eina_Cpu_Features eina_cpu_features_get(void)
{
   Eina_Cpu_Features ecf = 0;
#if defined(__i386__) || defined(__x86_64__)
   _x86_simd(&ecf);
#endif
   return ecf;
}

static int _cpu_count = -1;

static int
_eina_cpu_count_internal(void)
{
#ifdef EFL_HAVE_THREADS

# if   defined (_WIN32)
   SYSTEM_INFO sysinfo;

   GetSystemInfo(&sysinfo);
   return sysinfo.dwNumberOfProcessors;

# elif defined (__sun) || defined(__GNU__)
   /*
    * _SC_NPROCESSORS_ONLN: number of processors that are online, that
                            is available when sysconf is called. The number
                            of cpu can change by admins.
    * _SC_NPROCESSORS_CONF: maximum number of processors that are available
                            to the current OS instance. That number can be
                            change after a reboot.
    * _SC_NPROCESSORS_MAX : maximum number of processors that are on the
                            motherboard.
    */
   return sysconf(_SC_NPROCESSORS_ONLN);

# elif defined (__FreeBSD__) || defined (__OpenBSD__) || \
   defined (__NetBSD__) || defined (__DragonFly__) || defined (__MacOSX__) || \
   (defined (__MACH__) && defined (__APPLE__))

   int mib[4];
   int cpus;
   size_t len = sizeof(cpus);

   mib[0] = CTL_HW;
#ifdef HW_AVAILCPU
   mib[1] = HW_AVAILCPU;
#else
   mib[1] = HW_NCPU;
#endif
   sysctl(mib, 2, &cpus, &len, NULL, 0);
   if (cpus < 1)
      cpus = 1;

   return cpus;
   
/* musl modifications */   
#elif defined (__linux__)
  #include <sys/select.h>
  #define cpu_set_t fdset 
  #define CPU_ZERO FD_ZERO
  #define CPU_ISSET FD_ISSET
  int cpus = get_nprocs(void);
   return cpus;
/* returning 1 most likely disables threading */   
/* end of musl modifications */

# else
#  error "eina_cpu_count() error: Platform not supported"
# endif
#else
   return 1;
#endif
}

EAPI int eina_cpu_count(void)
{
   return _cpu_count;
}

void eina_cpu_count_internal(void)
{
   if (getenv("EINA_CPU_FAKE"))
     _cpu_count = atoi(getenv("EINA_CPU_FAKE"));
   else
     _cpu_count = _eina_cpu_count_internal();
}
