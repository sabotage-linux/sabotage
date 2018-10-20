This change file can be used to modify mmotype. The resulting program mmoimg
can be used to convert an mmo file into an image file containing a byte by byte
image of the memory after loading the input mmo into it.

@x
\def\title{MMOTYPE}
@y
\def\title{MMOIMG}
@z

@x
@* Introduction. This program reads a binary \.{mmo} file output by
the \MMIXAL\ processor and lists it in human-readable form. It lists
only the symbol table, if invoked with the \.{-s} option. It lists
also the tetrabytes of input, if invoked with the \.{-v} option.
@y
@* Introduction. This program reads a binary \.{mmo} file output by
the \MMIXAL\ processor and extracts from it an image file. The image file
will contain a true image of the MMIX memory after loading the input mmo file.
Such an image can be used, for example, as an image file for the ROM simulator
of the Virtual Motherboard project. A base address for the image file can be 
specified on the command line with the \.{-b hexnumber}. 
The first byte in the image file corresponds
to the memory byte at this address. Bytes with lower addresses are ignored.
The base address is rounded down to a multiple of 4. The default base
address is 8000 0000 0000 0000 creating an image of the operating system memory.

This program was written by Martin Ruckert as a change file to the mmotype
program of Donald E. Knuth.
@z
#include <string.h>
@x
#include <string.h>
@y
#include <string.h>
#include <ctype.h>
@z

@x
  @<List the symbol table@>;
@y
  if (listing) { @<List the symbol table@>; }
  @<Write the image file@>;
@z

@x
@ @<Process the command line@>=
listing=1, verbose=0;
for (j=1;j<argc-1 && argv[j][0]=='-' && argv[j][2]=='\0';j++) {
  if (argv[j][1]=='s') listing=0;
  else if (argv[j][1]=='v') verbose=1;
  else break;
}
if (j!=argc-1) {
  fprintf(stderr,"Usage: %s [-s] [-v] mmofile\n",argv[0]);
@.Usage: ...@>
  exit(-1);
}
@y
@ @<Process the command line@>=
listing=0, verbose=0,base.h=0x80000000,base.l=0;
for (j=1;j<argc-1 && argv[j][0]=='-' && argv[j][2]=='\0';j++) {
  if (argv[j][1]=='l') listing=1;
  else if (argv[j][1]=='v') verbose=1;
  else if (argv[j][1]=='b' && j<argc-2) base=scan_hex(argv[++j]);
  else if (argv[j][1]=='u' && j<argc-2) upper=scan_hex(argv[++j]);  
  else break;
}
base.l &=~3;
if (verbose) printf("base: %08X%08X\n",base.h, base.l);
if (verbose) printf("to  : %08X%08X\n",upper.h, upper.l);
if (j!=argc-1) {
  fprintf(stderr,"Usage: %s [-l] [-v] [-b hexbase] [-u hexlimit] mmofile\n"
                 "       -l          show listing\n"
                 "       -v          be verbose\n"
                 "       -b hexbase  start image at hexbase "
		 "(default #8000000000000000)\n"
                 "       -u hexlimit stop image before upper hexlimit (default"
		 " #FFFFFFFFFFFFFFFF)\n",argv[0]);
@.Usage: ...@>
  exit(-1);
}
  
@ @<Sub...@>=
octa scan_hex @,@,@[ARGS((char*))@];@+@t}\6{@>
octa scan_hex(p)
  char *p;
{ octa o = {0,0};
  if (p[0]=='0' && p[1]=='x') p=p+2;
  else if (p[0]=='#') p=p+1;
  for (;isxdigit(*p);p++) {
    int d;
    if (*p>='a') d=*p-'a'+10;
    else if (*p>='A')  d=*p-'A'+10;
    else d = *p-'0';
    o.h = (o.h<<4)+((o.l>>(32-4))&0xF);
    o.l = (o.l<<4)+d;
  }
  return o;
}
@z

@x
@ @<Glob...@>=
int listing; /* are we listing everything? */
int verbose; /* are we also showing the tetras of input as they are read? */
FILE *mmo_file; /* the input file */
@y
@ @<Glob...@>=
int listing = 0; /* are we listing everything? */
int verbose = 0; /* are we also showing the tetras of input as they are read? */
octa base = {0x80000000,0};   /* the start address of the immage */
octa upper = {0xFFFFFFFF,0xFFFFFFFF};
FILE *mmo_file; /* the input file */
FILE *image_file; /* the output file */
char *image_file_name;
@z

@x
  if (listing) @<List |tet| as a normal item@>;
@y
  store_image(cur_loc,tet);
  if (listing) @<List |tet| as a normal item@>;
  cur_loc=incr(cur_loc,4);@+ cur_loc.l &=-4;
@z

@x
  cur_loc=incr(cur_loc,4);@+ cur_loc.l &=-4;
@y
@z

@x
 if (listing) printf("%08x%08x: %08x%08x\n",tmp.h,tmp.l,cur_loc.h,cur_loc.l);
 continue;
@y
 store_image(tmp, cur_loc.h);
 if (listing) printf("%08x%08x: %08x\n",tmp.h,tmp.l,cur_loc.h);
 tmp=incr(tmp,4);
 store_image(tmp, cur_loc.l);
 if (listing) printf("%08x%08x: %08x\n",tmp.h,tmp.l,cur_loc.l);
 continue;
@z

@x
fixr: tmp=incr(cur_loc,-(delta>=0x1000000? (delta&0xffffff)-(1<<j): delta)<<2);
 if (listing) printf("%08x%08x: %08x\n",tmp.h,tmp.l,delta);
 continue;
@y
fixr: tmp=incr(cur_loc,-(delta>=0x1000000? (delta&0xffffff)-(1<<j): delta)<<2);
 store_image(tmp,delta);
 if (listing) printf("%08x%08x: %08x\n",tmp.h,tmp.l,delta);
 continue;
@z

@x
@* Index.
@y
@* Writing the image file.
We first write the image to a long array of tetras keeping track
of the highest index we used in writing.

@d max_image_tetras 0x100000

@<Glob...@>=
tetra image[max_image_tetras];
int image_tetras = 0;

@ We fill the array using this function. It checks that the 
location is greater or equal to base and less than the upper bound.
The program terminates with an error message if the output will not fit into the image.
If the listing is enabled, an asterisk will precede lines that produce entries in the
image file.

@<Sub...@>=
void store_image @,@,@[ARGS((octa, tetra))@];
void store_image(loc,tet)
octa loc;
tetra tet;
{ int i;
  octa x;
  if ((loc.h<base.h || (loc.h==base.h && loc.l<base.l)) ||
      (upper.h<loc.h || (upper.h==loc.h && upper.l<=loc.l)))
  { if (listing) printf("  "); return; }
  if (listing) printf("* ");
  x.h=loc.h-base.h;@+
  x.l=loc.l-base.l;
  if (x.l>loc.l) x.h--;
  i = x.l>>2;
  if (x.h!=0 || i>=max_image_tetras) 
  { fprintf(stderr,"Location %08x%08x to large for image (max %x)",
  loc.h,loc.l, max_image_tetras*4);
    exit(1);
  }
  image[i] ^= tet;
  if (i>= image_tetras) image_tetras=i+1;
}

@ Before we can open the output file, we have to determine a filename for the output file.
  We either replace the extension .mmo or .MMO of the input file name by .img (for image) or
  we append the extension .img to the input file name.

@<Open the image file@>=
  { char *extension;
    image_file_name = (char*)calloc(strlen(argv[argc-1])+5,1);
    if (!image_file_name) {
      fprintf(stderr,"No room to store the file name!\n");@+exit(-4);
    }
    strcpy(image_file_name,argv[argc-1]);
    extension = image_file_name+strlen(image_file_name)-4;
    if (strcmp(extension,".mmo")==0 || strcmp(extension,".mmo")==0)
      strcpy(extension,".img");
    else
      strcat(image_file_name,".img");
    image_file=fopen(image_file_name,"wb");
    if (!image_file) 
    { fprintf(stderr,"Can't open file %s!\n","bios.img");
      exit(-3);
    }
  }
  
@ Last not least we can
@<Write the image file@>=
  @<Open the image file@>
  { int i;
    unsigned char buffer[4];
    tetra tet;
    printf("Writing %d byte to image file %s\n",image_tetras*4,image_file_name);
    for (i=0;i<image_tetras;i++)  
    { tet = image[i]; 
      buffer[0] = (tet>>(3*8))&0xFF;
      buffer[1] = (tet>>(2*8))&0xFF;
      buffer[2] = (tet>>(1*8))&0xFF;
      buffer[3] = (tet)&0xFF;
      fwrite(buffer,1,4,image_file);
    }
  }
  fclose(image_file);

@* Index.
@z
