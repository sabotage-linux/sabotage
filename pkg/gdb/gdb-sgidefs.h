#ifndef _SGIDEFS_H
#define _SGIDEFS_H

/* MIPS ABI crap that GLIBC puts into /include
   by default, and GDB depends on it happily. */

#define _MIPS_ISA_MIPS1 1
#define _MIPS_ISA_MIPS2 2
#define _MIPS_ISA_MIPS3 3
#define _MIPS_ISA_MIPS4 4
#define _MIPS_ISA_MIPS5 5
#define _MIPS_ISA_MIPS32 6
#define _MIPS_ISA_MIPS64 7

#ifndef _ABIO32
#define _ABIO32 1
#endif
#define _MIPS_SIM_ABI32 _ABIO32

#ifndef _ABIO32
#define _ABIO32 1
#endif
#define _MIPS_SIM_ABI32 _ABIO32

#ifndef _ABIN32
#define _ABIN32 2
#endif
#define _MIPS_SIM_NABI32 _ABIN32

#ifndef _ABI64
#define _ABI64 3
#endif
#define _MIPS_SIM_ABI64 _ABI64

#endif
