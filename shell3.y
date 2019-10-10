
/*
 * CS-252
 * shell.y: parser for shell
 *
 * This parser compiles the following grammar:
 *
 *	cmd [arg]* [> filename]
 *
 * you must extend it to understand the complete shell grammar
 *
 */

%code requires 
{
#include "string.h"

#if __cplusplus > 199711L
#define register      // Deprecated in C++11 so remove the keyword
#endif
}

%union
{
  char *string_val;
}

%token <string_val> WORD BACKTICK ENVVAR
%token NOTOKEN GREAT NEWLINE ANDP PIPE DGREAT LESS TWOGREAT GREATAND DGREATAND

%{
//#define yylex yylex
#include <stdio.h>
#include <sys/types.h>
#include "command.h"
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>
#include <dirent.h>
#include <regex.h>

extern int lastpid;
extern char * lastarg;
extern int lastback;
extern char * pathTo;
void yyerror(const char * s);
int yylex();

%}

%%

goal:
  commands
  ;

commands:
  command
  | commands command
  ;

command: simple_command
       ;

simple_command:	
  pipe_commands multiple_io background_process NEWLINE {
   // printf("   Yacc: Execute command\n");
    command_execute(current_command);
//    Command::_currentCommand.execute();
  }
  | NEWLINE 
  | error NEWLINE { yyerrok; }
  ;

pipe_commands:
  command_and_args
  | pipe_commands pipe_command
  ;

pipe_command:
  PIPE command_and_args {
     //printf("	Yacc: Pipe command\n");
  }
  ;

command_and_args:
  command_word argument_list {
    Command::_currentCommand.
    insertSimpleCommand( Command::_currentSimpleCommand );
  }
  ;

argument_list:
  argument_list argument
  | /* can be empty */
  ;

argument:
  WORD {
//	printf("Recieved WORD : %s\n", $1);
    //printf("   Yacc: insert argument \"%s\"\n", $1);
    
    	if (strstr($1,"?") != NULL || strstr($1,"*") != NULL) {
		char * reg = (char*)malloc(2*strlen($1)+10);
		char * a = $1;
		char * r = reg;
		*r = '^'; r++;
		while (*a) {
			if (*a == '*') { *r='.'; r++; *r='*'; r++; }
			else if (*a == '?') { *r='.' ; r++;}
			else if (*a == '.') { *r='\\'; r++; *r='.'; r++;}
			else { *r=*a; r++;}
			a++;
		}
		*r='$'; r++; *r=0;
		regex_t rgt;
		int expbuf = regcomp(&rgt, reg, REG_EXTENDED | REG_NOSUB); 
		regmatch_t match;
		DIR * dir = opendir(".");
		struct dirent * ent;
		//printf("%s\n", reg);
		while ((ent = readdir(dir)) != NULL) {
			if (regexec(&rgt, ent->d_name, 1, &match, 0) == 0) {
				//printf("%s", ent->d_name);
				Command::_currentSimpleCommand->insertArgument(strdup(ent->d_name));
			}
		}
		closedir(dir);
	} else {

    /*
    char * actWord = $1;
   
    if (actWord[0] == '"') {
	actWord++;
	char * crawler = actWord;
	while (crawler[0] != '\0' && crawler[0] != '"') {
		crawler++;
	}

	crawler[0] = '\0';
    }
    */    
	char * actWord = $1;
	char * crawler = actWord;
	char * newWord = strdup($1);
	char * newCraw = newWord;
	
	int inQuotes = 0;

	if (crawler[0] == '"') {
		inQuotes = 1;
		crawler++;
	}


	while (crawler[0] != '\0') {
		//printf("In here for %s\n", $1);

		int count = 0;
		int trans = 0;
		if (crawler[0] == 92) {
			count = 0;
			char * counter = crawler;
			while (counter[0] == 92) {
				count++;
				counter++;
			}

			trans = (count+2)/4;
			int i = 0;

			crawler+=count;
			for (i = 0; i < trans; i++) {
				newCraw[0] = 92;
				newCraw++;
			}				
		} else {
			newCraw[0] = crawler[0];
			crawler++;
			newCraw++;
		}			
	}

	if (inQuotes == 1)
		newCraw--;

	newCraw[0] = '\0';

	

	//printf("\n\n%s\n\n", newWord); 


    Command::_currentSimpleCommand->insertArgument(newWord);
	}
  }
  | BACKTICK {
     int oldstd0 = dup(0);
     int oldstd1 = dup(1);
     int pip[2];
     int pip2[2];
     pipe(pip);
     pipe(pip2);
//     printf("pip[%d,%d] pip2[%d,%d]\n",pip[0],pip[1],pip2[0],pip2[1]);
     char buffer[1024];
//   char testbuf[1024];     
     char buf1[1024];
     char buf2[1024];
     char buf3[1024];
     char buf4[1024];

     int child = fork();
     if (child == 0) {

	/*
	printf("Input shit : %s\n",$1);
	dup2(pip[0], 0);
	dup2(pip[1], 1);
	write(pip[1], $1, strlen($1));
	read(pip[0], buffer, 1024);
	dup2(oldstd0, 0);
	dup2(oldstd1, 1);
	printf("Output shit : %s\n", buffer);
	*/
//	printf("%s", $1);
	write(pip[1], $1, strlen($1));
	
	dup2(pip[0],0);
	dup2(pip2[1],1);

	close(pip[1]);
     
	char * cmd = "/home/u95/braftery/cs252/lab3-src/shell";
	char * argv[1];
	argv[0] = "/home/u95/braftery/cs252/lab3-src/shell";
	execlp(cmd, argv[0], NULL);
//	printf("Done\n");
     } else { // in parent
	close(pip[1]);
	waitpid(child, NULL, 0);
	//printf("Parent PID : %d\n", getpid());
	//printf("\nPast Wait\n");

	char bufboi[1024];
	int i;
	while (1 < 2) {
		read(pip2[0], &bufboi[i], 1);
		if(bufboi[i] == '\n') {
			bufboi[i] = '\0';
			break;
		}
		i++;
	}
	//read(pip2[0], buffe, 1024);

	Command::_currentSimpleCommand->insertArgument(strdup(bufboi));
     	dup2(oldstd0, 0);
	dup2(oldstd1, 1);
//	printf("BUFFBOI : %s\n", bufboi);
//	printf("Test Bufs\n%s\n%s\n%s\n%s\n", buf1, buf2, buf3, buf4);
     }
  }
  | ENVVAR {
	if (!strcmp($1,"?")) {
		char buffer[100];
		sprintf(buffer, "%d", lastpid);
		Command::_currentSimpleCommand->insertArgument(strdup(buffer));
	} else if (!strcmp($1,"_")) {
		char buffer[100];
		sprintf(buffer, "%s", lastarg);
		Command::_currentSimpleCommand->insertArgument(strdup(buffer));
	} else if (!strcmp($1,"$")) {
		char buffer[100];
		int pid = getpid();
		sprintf(buffer, "%d", pid);
		Command::_currentSimpleCommand->insertArgument(strdup(buffer));
	} else if (!strcmp($1,"!")) {
		char buffer[100];
		sprintf(buffer, "%d", lastback);
		Command::_currentSimpleCommand->insertArgument(strdup(buffer));	
	} else if (!strcmp($1,"SHELL")) {
		Command::_currentSimpleCommand->insertArgument(strdup(pathTo));	
	} else
	Command::_currentSimpleCommand->insertArgument(strdup(getenv($1)));
  }
  ;

command_word:
  WORD {
    //printf("   Yacc: insert command \"%s\"\n", $1);
    Command::_currentSimpleCommand = new SimpleCommand();
    Command::_currentSimpleCommand->insertArgument($1 );
  }
  ;

multiple_io:
   iomodifier_opt {
//		printf("TEST\n");
	}
   | iomodifier_opt multiple_io {
//		printf("TEST2");
	}
   ;

iomodifier_opt:
   output_redir input_redir error_redir outerror_redir append_out append_outerror
   ;

output_redir:
  GREAT WORD {
	//printf("Yacc at GREAT");
	if (Command::_currentCommand._outFile) {
		printf("Ambiguous output redirect\n");
		Command::_currentCommand._ambig = 1;
	}
   // printf("   Yacc: insert output \"%s\"\n", $2);
    Command::_currentCommand._outFile = $2;
  }
  |  
  ;

append_out:
  DGREAT WORD {
    //printf("	Yacc: append output \"%s\"\n", $2);
   if (Command::_currentCommand._outFile) {
	printf("Ambiguous output redirect\n");
	Command::_currentCommand._ambig = 1;
   }
    Command::_currentCommand._outFile = $2;
    Command::_currentCommand._oAppend = 1;
  }
  |
  ;

input_redir:
  LESS WORD {
      if (Command::_currentCommand._inFile) {
	printf("Ambiguous input redirect\n");
	Command::_currentCommand._ambig = 1;
      }

    //printf("    Yacc: redirect input \"%s\"\n", $2);
    Command::_currentCommand._inFile = $2;
  }
  |
  ;

error_redir:
  TWOGREAT WORD {
      if (Command::_currentCommand._errFile) {
		printf("Ambiguous error redirect\n");
      		Command::_currentCommand._ambig = 1;	
	}

    //printf("  	Yacc: redirect err output \"%s\"\n", $2);
    Command::_currentCommand._errFile = $2;
  }
  |
  ;

outerror_redir:
  GREATAND WORD {
	if (Command::_currentCommand._errFile) {
		printf("Ambiguous error redirect\n");
		Command::_currentCommand._ambig = 1;
	}
if (Command::_currentCommand._outFile) {
	printf("Ambiguous output redirect\n");
	Command::_currentCommand._ambig = 1;
}
    //printf("	Yacc: redirect err and output \"%s\"\n", $2);
    Command::_currentCommand._outFile = $2;
    Command::_currentCommand._errFile = $2;
  }
  |
  ;

append_outerror:
   DGREATAND WORD {
    //printf("	Yacc: append err and output \"%s\"\n", $2);
	if (Command::_currentCommand._errFile) {
		printf("Ambiguous error redirect\n");
		Command::_currentCommand._ambig = 1;
	}
if (Command::_currentCommand._outFile) {
	printf("Ambiguous output redirect\n");
	Command::_currentCommand._ambig = 1;
}
    Command::_currentCommand._errFile = $2;
    Command::_currentCommand._outFile = $2;
    Command::_currentCommand._oAppend = 1;
    Command::_currentCommand._eAppend = 1;
   }
   |
   ;

background_process:
   ANDP {
    Command::_currentCommand._background = 1;
    //printf("	Yacc: background process\n");
   }
   |
   ;
%%

void
yyerror(const char * s)
{
  fprintf(stderr,"%s", s);
}

#if 0
main()
{
  yyparse();
}
#endif
