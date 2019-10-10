
/*
 *
 * CS-252 Fall 2017
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include "y.tab.h"
#include <string.h>
#include <unistd.h>

extern char * read_line();

int mygetc(FILE * f) {
static char *p;
char ch;

if (!isatty(0) || 1 == 1 ) {
 // stdin is not a tty. Call real getc
 return getc(f);
}

// stdin is a tty. Call our read_line.

if (p==NULL || *p == 0) {
 char * s;// = read_line();
 p = s;
}

//ch = *p;
p++;

return ch;
}

#undef getc
#define getc(f) mygetc(f)


static  void yyunput (int c,char *buf_ptr  );

void myunputc(int c) {
  unput(c);
}

%}

%%

\n {
  return NEWLINE;
}

[ \t] {
  /* Discard spaces and tabs */
}

"|" {
  return PIPE;
}
">" {
  return GREAT;
}


">>" {
  return DGREAT;
}

"<" {
  return LESS;
}

"2>" {
  return TWOGREAT;
}

">>&" {
  return DGREATAND;
}

">&" {
  return GREATAND;
}
"&" {
  return ANDP;
}

"~" {
  return TILDE;
}

`[^`]*` {
  yylval.string_val = strndup(yytext+1, yyleng-1);
  yylval.string_val[yyleng-2] = '\n';
  return BACKTICK;
}

\$\{[a-zA-Z_!?$]*\} {
  yylval.string_val = strndup(yytext+2, yyleng-3);
  return ENVVAR;
} 

[^ \t\n][^ \t\n]*  {
  /* Assume that file names have only alpha chars */
  yylval.string_val = strdup(yytext);
  return WORD;
}

\"[^"\n]*["\n] {
    //printf("\nIN THERE\n");
    int g = yyleng-2; 
    yylval.string_val = strdup(yytext+1);
    //printf("IN THE QUOTES  %s\n", yylval.string_val);
    if (yylval.string_val[g] == '"') {
	yylval.string_val[g] = 0;	
    }
  return WORD;
}
