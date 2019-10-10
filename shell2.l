/*
 *
 * CS 252 Summer 2018
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include <string.h>

#include "y.tab.h"

%}

%%

\n {
  return NEWLINE;
}

[ \t] {
  // Discard spaces and tabs

}

">" {
  return GREAT;
}

[^ \t\n][^ \t\n]* {
  // Assume that file names have only alpha chars

  yylval.string_val = strdup(yytext);
  return WORD;
}
