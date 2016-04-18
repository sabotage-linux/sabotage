#include<stdio.h>
#include<stdlib.h>
#include<sys/stat.h>
#include<time.h>
int main(int argc,char **argv)
{
	char *tableName;
	int pad,a,i,align,pos=0,lineLen=8,totalLen=0;
	FILE *fin = stdin,*fout = stdout;
	
	if (argc < 2 || argc > 3) {
		fprintf(stderr, "%s tableName [pad] < inputFile > outputFile\n ", argv[0]);
		return 1;
	}
	tableName=argv[1];
	pad = argc == 3 ?  atoi(argv[2]) : 1;

	fprintf(fout, "unsigned char %s[] = {\n",tableName);
	fprintf(fout, "\t");
	for (a = fgetc(fin); a != EOF ; a = fgetc(fin)) {
		totalLen++;
		if (pos >= lineLen ) {
			fprintf(fout ,",\n\t");
			pos=0;
		} else if (pos > 0)
			fprintf(fout,", ");
		
		fprintf(fout, "0x%02x", a);
		pos++;

	}

	align= totalLen % pad;
	if (align != 0) {
		a = pad - align;
		totalLen+=a;
		for (i=0;i<a;i++) {
			if (pos >= lineLen ) {
				fprintf(fout, ",\n\t");
				pos=0;
			} else if (pos > 0) 
				fprintf(fout, ", ");
			else 
				fprintf(fout, "\t");
			fprintf(fout, "0x00");
			pos++;
		}		
	}
	fprintf (fout, "\n};\n\nconst unsigned int %s_len = %i;\n", tableName, totalLen);

	struct stat st;
	if (fstat(fileno(fin), &st) == -1) {
		perror("fstat");
		return 1;
	}
	fprintf (fout,"\nconst int %s_mtime = %ld;\n", tableName, st.st_mtime);

	return 0;
}

