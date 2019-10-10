//
// CS-252
// shell.y: parser for shell
//
// This parser compiles the following grammar:
//
//   cmd [arg]* [> filename]
//
// you must extend it to understand the complete shell grammar
//


// define all tokens that are used in the lexer here:

%token <string_val> WORD BACKTICK ENVVAR
%token NOTOKEN GREAT NEWLINE ANDP PIPE DGREAT LESS TWOGREAT GREATAND DGREATAND
       TILDE

%union {
  // specify possible types for yylval, for access in shell.l

  char *string_val;

  // int numerical_val;
}

%{

#include <stdio.h>

#include "command.h"
#include <sys/wait.h>
#include <unistd.h>
#include <dirent.h>
#include <regex.h>
#include <sys/types.h>
#include <string.h>
#include <stdlib.h>

// yyerror() is defined at the bottom of this file

void yyerror(const char * s);
void expand_wildcard(const char *prefix, const char *suffix);

extern int last_pid;
extern char *last_arg;
extern int last_back;


// We must offer a forward declaration of yylex() since it is
// defined by flex and not available until linking.

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

command:
  simple_command
  ;

simple_command:
  pipe_commands multiple_io background_process NEWLINE {
    command_execute(current_command);
  }
  | NEWLINE
  | error NEWLINE {
    yyerrok;
  }
  ;

pipe_commands:
  command_and_args
  | pipe_commands pipe_command
  ;

pipe_command:
  PIPE command_and_args {

  }
  ;

command_and_args:
  command_word argument_list {
    command_insert_simple_command(current_command, current_simple_command);
  }
  ;

argument_list:
  argument_list argument
  | // can be empty
  ;

argument:
  WORD {

    // WILDCARDING HERE

    if ((strstr($1, "?") != NULL) || (strstr($1, "*") != NULL)) {
      expand_wildcard("", $1);
    }
    else {
      char *actual_word = $1;
      char *crawler = actual_word;
      char *new_word = strdup($1);
      char *new_crawler = new_word;

      int in_quotes = 0;

      if (crawler[0] == '"') {
        in_quotes = 1;
        crawler++;
      }

      while (crawler[0] != '\0') {
        int count = 0;
        int trans = 0;
        if (crawler[0] == '\\') {
          count = 0;
          char *counter = crawler;
          while (counter[0] == '\\') {
            count++;
            counter++;
          }

          trans = (count+2)/4;
          int i = 0;
          crawler += count;
          for (i = 0; i < trans; i++) {
            new_crawler[0] = '\\';
            new_crawler++;
          }
        }
        else {
          new_crawler[0] = crawler[0];
          crawler++;
          new_crawler++;
        }
      }

      if (in_quotes == 1) {
        new_crawler--;
      }

      new_crawler[0] = '\0';

      simple_command_insert_argument(current_simple_command, new_word);
    }
  }
  | BACKTICK {
/*    int old_std0 = dup(0);
    int old_std1 = dup(1);
    int pip[2];
    int pip2[2];
    pipe(pip);
    pipe(pip2);
    char buffer[1024];
    write(pip[1], $1, strlen($1));

    int child = fork();

    if (child == 0) {

      dup2(pip[0], 0);
      dup2(pip[1], 1);

      close(pip[1]);

//      char *cmd = "/homes/braftery/cs252/lab3-src/shell";
//      char *argv[1];
//      argv[0] = "/homes/braftery/cs252/lab3-src/shell";

      execlp("/homes/braftery/cs252/lab3-src/shell", 
             "/homes/braftery/cs252/lab3-src/shell", NULL);
    }
    else {
      close(pip[1]);
      waitpid(child, NULL, 0);
      close(pip2[1]);

      char pipe_buffer[1024];
      char small_buffer[256];
      int i = 0;
      int j = 0;
      while (1 < 2) {
        read(pip2[0], &pipe_buffer[i], 1);

        if (pipe_buffer[i] != EOF && pipe_buffer != NULL) {
          small_buffer[j] = pipe_buffer[i];
          j++;
        }
        if (pipe_buffer[i] == '\n' || pipe_buffer[i] == ' ') {
          small_buffer[--j] = '\0';
          pipe_buffer[i] = ' ';
          simple_command_insert_argument(current_simple_command, 
                                          strdup(small_buffer));
          j = 0;
        }
        if (pipe_buffer[i] == EOF || pipe_buffer[i] == '\0') {
          pipe_buffer[i] = '\0';
          break;
        }
        i++;
      }

      dup2(old_std1, 1);
      dup2(old_std0, 0); 
    } */
     int oldstd0 = dup(0); /*Save old stdin*/
     int oldstd1 = dup(1); /*Save old stdout*/
     int pip[2]; /*first pipe*/
     int pip2[2]; /*second pipe*/
     pipe(pip);   /* create pipes */
     pipe(pip2);
     char buffer[1024];
     write(pip[1], $1, strlen($1));
     int child = fork();

     if (child == 0) {

	
	dup2(pip[0],0);
	dup2(pip2[1],1);

	close(pip[1]);

	/* Execute shell and pas in commands through pipe */
	execlp("/homes/braftery/cs252/lab3-src/shell", "/homes/braftery/cs252/lab3-src/shell", NULL);
	dprintf(1,"BANANA");
     } else { // in parent
	
	close(pip[1]);
//	close(pip2[1]);
	waitpid(child, NULL, 0);
	close(pip2[1]);
	char bufboi[1024];
	char smolbuf[256];
	int i = 0;
	int j = 0;
	while (1 < 2) {
		/* replace newlines with spaces and go till end of file */
		read(pip2[0], &bufboi[i], 1);

		if (bufboi[i] != EOF && bufboi != NULL) {
			smolbuf[j] = bufboi[i];
			j++;
		}
		if(bufboi[i] == '\n' || bufboi[i] == ' ') {
			smolbuf[--j] = '\0';
			bufboi[i] = ' ';
      simple_command_insert_argument(current_simple_command, strdup(smolbuf));
//			Command::_currentSimpleCommand->insertArgument(strdup(smolbuf));
			j = 0;
		}
		if (bufboi[i] == EOF || bufboi[i] == '\0') {
			bufboi[i] = '\0';
			break;
		}
		i++;
	}

	/* Replace subshell section with output of subshell */	
//	Command::_currentSimpleCommand->insertArgument(strdup(bufboi));
	dup2(oldstd0, 0);
	dup2(oldstd1, 1);

  }

  } 
  | ENVVAR {
    if (!strcmp($1, "?")) {
      char buffer[100];
      sprintf(buffer, "%d", last_pid);
      simple_command_insert_argument(current_simple_command, strdup(buffer));
    }
    else if (!strcmp($1, "_")) {
      char buffer[100];
      sprintf(buffer, "%s", last_arg);
      simple_command_insert_argument(current_simple_command, strdup(buffer));
    }

    else if (!strcmp($1, "$")) {
      char buffer[100];
      int pid = getpid();
      sprintf(buffer, "%d", pid);
      simple_command_insert_argument(current_simple_command, strdup(buffer));    
    }
    else if (!strcmp($1, "!")) {
      char buffer[100];
      sprintf(buffer, "%d", last_back);
      simple_command_insert_argument(current_simple_command, strdup(buffer));
    }
    else if (!strcmp($1, "SHELL")) {
      char buffer[100];
      sprintf(buffer, "/home/u95/braftery/cs252/lab3-src/shell");
      simple_command_insert_argument(current_simple_command, strdup(buffer));
    }
    else {
      simple_command_insert_argument(current_simple_command, strdup(getenv($1)));
    }
  }  
  ;

command_word:
  WORD {
    current_simple_command = simple_command_create();
    simple_command_insert_argument(current_simple_command, $1);
  }
  ;

multiple_io:
  iomodifier_opt
  | iomodifier_opt multiple_io
  ;

iomodifier_opt:
  output_redir input_redir error_redir outerror_redir append_out append_outerror
  ;

output_redir:
  GREAT WORD {
    if (current_command->has_output) {
      current_command->ambiguous = 1;
      printf("Ambiguous output redirect.\n");
    }
    current_command->out_file = $2;
    current_command->has_output = 1;
  }
  |
  ;

append_out:
  DGREAT WORD {
    if (current_command->has_output) {
      current_command->ambiguous = 1;
      printf("Ambiguous output redirect.\n");
    }
    current_command->out_file = $2;
    current_command->has_output = 1;
    current_command->append_out = 1;
  }
  |
  ;

input_redir:
  LESS WORD {
    if (current_command->has_input) {
      current_command->ambiguous = 1;
      printf("Ambiguous input redirect.\n");
    }
    current_command->in_file = $2;
    current_command->has_input = 1;
  }
  |
  ;

error_redir:
  TWOGREAT WORD {
    if (current_command->has_error) {
      current_command->ambiguous = 1;
      printf("Ambiguous error redirect.\n");
    }
    current_command->err_file = $2;
    current_command->has_error = 1;
  }
  |
  ;

outerror_redir:
  GREATAND WORD {
    if (current_command->has_error) {
      current_command->ambiguous = 1;
      printf("Ambiguous error redirect.\n");
    }
    if (current_command->has_output) {
      current_command->ambiguous = 1;
      printf("Ambiguous output redirect.\n");
    }
    current_command->out_file = $2;
    current_command->err_file = $2;
    current_command->has_output = 1;
    current_command->has_error = 1;
  }
  |
  ;

append_outerror:
  DGREATAND WORD {
    if (current_command->has_error) {
      current_command->ambiguous = 1;
      printf("Ambiguous error redirect.\n");
    }
    if (current_command->has_output) {
      current_command->ambiguous = 1;
      printf("Ambiguous outpur redirect.\n");
    }
    current_command->err_file = $2;
    current_command->out_file = $2;
    current_command->append_out = 1;
    current_command->append_err = 1;
    current_command->has_error = 1;
    current_command->has_output = 1;
  }
  |
  ;

background_process:
  ANDP {
    current_command->is_background = 1;
  }
  |
  ;
%%

void expand_wildcard(const char *prefix, const char *suffix) {
/*
  int first = 1;
  int hidden = 1;
  int last = 1;

  if (suffix[0] == '.') {
    hidden = 0;
  }

  char *temp_suffix = strdup(suffix);

  char *component;

  if (temp_suffix[0] != '\0') {
    component = strchr(temp_suffix, '/');

    if (component != NULL) {
      component[1] = '\0';
    }

    if (component == NULL) {
      if (prefix[0] == '\0') {
        first = 0;
      }
    }
    component = temp_suffix;
  }
  else {
    return;
  }

  if ((strstr(component, "?") == NULL) && (strstr(component, "*") == NULL)) {
    if (strchr(component, '/') == NULL) {
      char *add = (char *) malloc(strlen(prefix) + strlen(suffix) + 1);
      strcpy(add, prefix);
      strcat(add, suffix);
      simple_command_insert_argument(current_simple_command, strdup(add));
      free(add);
      add = NULL;
      return;
    }

    strchr(component, '/')[1] = '\0';
    char *new_pre = (char *) malloc(strlen(prefix) + strlen(component) + 1);
    char *duplicate = strdup(suffix);
    char *new_suf = strchr(duplicate, '/');
    new_suf ++;
    strcpy(new_pre, prefix);
    strcpy(new_pre, component);
    expand_wildcard(strdup(new_pre), strdup(new_suf));
    free(new_pre);
    new_pre = NULL;
    return;
  }

  char *end = strchr(component, '/');
  if (end != NULL) {
    end[0] = '\0';
  }

  char *dup = strdup(suffix);
  char *last_check = strchr(dup, '/');

  if ((last_check == NULL) || (last_check[1] == '\0')) {
    last = 0;
  }

  free(dup);
  dup = NULL;

  if ((strstr(component, "?") != NULL) || (strstr(component, "*") != NULL)) {
    char *reg = (char *) malloc(2 * strlen(component) + 10);
    char *a = component;
    char *r = reg;
    *r = '^';
    r++;

    while (*a) {
      if (*a == '*') {
        *r = '.';
        r++;
        *r = '*';
        r++;
      }
      else if (*a == '?') {
        *r = '.';
        r++;
      }
      else if (*a == '.') {
        *r = '\\';
        r++;
        *r = '.';
        r++;
      }
      else {
        *r = *a;
        r++;
      }
      a++;
    }

    *r = '$';
    r++;
    *r = 0;

    regex_t rgt;
    int expbuf = regcomp(&rgt, reg, REG_EXTENDED | REG_NOSUB);
    regmatch_t match;
    char *direc = (char *) malloc(strlen(prefix) + strlen(component) + 1);
    strcpy(direc, prefix);
    DIR *dir;

    int where = 0;

    if (first == 1) {
      dir = opendir(direc);
      where = 1;
    }
    else {
      dir = opendir(".");
      where = 2;
    }

    struct dirent *ent;
    int max_entries = 20;
    int num_entries = 0;
    char **array = (char **) malloc(max_entries * sizeof(char *));

    while ((ent = readdir(dir)) != NULL) {
      if (regexec(&rgt, ent->d_name, 1, &match, 0) == 0) {
        if (num_entries == max_entries) {
          max_entries *= 2;
          array = (char **) realloc(array, max_entries * sizeof (char *));
        }
        array[num_entries] = strdup(ent->d_name);
        num_entries++;
      }
    }

    closedir(dir);

    // Sort entries    

    for (int a = 0; a < num_entries; a++) {
      for (int b = 0; b < num_entries - 1; b++) {
        if (strcmp(array[b], array[b + 1]) > 0) {
          char * temp = strdup(array[b]);
          array[b] = array[b + 1];
          array[b + 1] = temp;
        }
      }
    }

    // Add entries as arguments

    for (int i = 0; i < num_entries; i++) {
      if (array[i][0] != '.' || hidden == 0) {
        if ((strchr(array[i], '/') == NULL) ||
            (strchr(array[i], '/')[1] == '\0')) {
          char *add = (char *) malloc(strlen(prefix) + strlen(array[i]) + 1);

          strcpy(add, prefix);
          strcat(add, array[i]);

          if (last == 0) {
            simple_command_insert_argument(current_simple_command, strdup(add));
          }
          else {
            char *duplicate = strdup(suffix);
            char *new_suf = strchr(duplicate, '/');
            new_suf++;
            strcat(add, "/");
            expand_wildcard(add, new_suf);
          }
          free(add);
          add = NULL;
        }
        else {
          expand_wildcard(array[i], suffix);
        }
      }
    }
    free(array);
    array = NULL;
  }
*/


    int first = 1;
    int hidden = 1;
    int last = 1;
    
    if (suffix[0] == '.') {
	    hidden = 0;
    }

    char * tempSuffix = strdup(suffix);

    char * component;
    if (tempSuffix[0] != '\0') {
        component = strchr(tempSuffix, '/');
		
	if (component != NULL)
		component[1] = '\0';
	if (component == NULL) {
		if (prefix[0] == '\0')
			first = 0;	
	} 

	component = tempSuffix;
    } else {
	return;
    }

    if (strstr(component,"?") == NULL && strstr(component,"*") == NULL) {
	if (strchr(component, '/') == NULL) {
		char * add = (char *) malloc(strlen(prefix)+strlen(suffix)+1);
		strcpy(add, prefix);
		strcat(add, suffix);
		simple_command_insert_argument(current_simple_command, strdup(add));
    //Command::_currentSimpleCommand->insertArgument(strdup(add));	
		free(add);
		return;
	} 
	strchr(component, '/')[1] = '\0';
	char * newPre = (char*) malloc(strlen(prefix)+strlen(component)+1);
	char * duplicate = strdup(suffix);
	char * newSuf = strchr(duplicate,'/');
	newSuf++;
	strcpy(newPre, prefix);
	strcat(newPre, component);
	expand_wildcard(strdup(newPre), strdup(newSuf));
	free(newPre);
	return;
    } 

    char * end = strchr(component, '/');
    if (end != NULL)
	end[0] = '\0';

    char * dup5 = strdup(suffix);
    char * lastCheck = strchr(dup5, '/');
    if (lastCheck == NULL || lastCheck[1] == '\0')
	last = 0;
    free(dup5);

    if (strstr(component,"?") != NULL || strstr(component,"*") != NULL) {
		char * reg = (char*)malloc(2*strlen(component)+10);
		char * a = component;
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
		char * direc = (char*)malloc(strlen(prefix)+strlen(component)+1);
		strcpy(direc, prefix);
		DIR * dir;
		if (first == 1)
			dir = opendir(direc);
		else
			dir = opendir(".");
		
		struct dirent * ent;
		int maxEntries = 20;
		int nEntries = 0;
		char ** array = (char**) malloc(maxEntries*sizeof(char*));
			
		while ((ent = readdir(dir)) != NULL) {
			if (regexec(&rgt, ent->d_name, 1, &match, 0) == 0) {
				if (nEntries == maxEntries) {
					maxEntries *= 2;
					array = (char**) realloc(array,maxEntries*sizeof(char*));		
				}
			
				array[nEntries] = strdup(ent->d_name);
				nEntries++;
			}
		}
	
		closedir(dir);

		for (int a = 0; a < nEntries; a++) {
			for (int b = 0; b < nEntries - 1; b++) {
				if (strcmp(array[b], array[b+1]) > 0) {
					char * temp = strdup(array[b]);
					array[b] = array[b+1];
					array[b+1] = temp;
				}
			}
		}

		for (int i = 0; i < nEntries; i++) {
			if (array[i][0] != '.' || hidden == 0) {
				if (strchr(array[i], '/') == NULL || strchr(array[i], '/')[1] == '\0') {
					char * add = (char*)malloc(strlen(prefix)+strlen(array[i])+1);
								
					strcpy(add, prefix);
					strcat(add, array[i]);
					if (last == 0)
					  simple_command_insert_argument(current_simple_command, strdup(add));
           	//Command::_currentSimpleCommand->insertArgument(strdup(add));
					else {
						char * duplicate = strdup(suffix);
						char * newSuf = strchr(duplicate,'/');
						newSuf++;
 						strcat(add, "/");
						expand_wildcard(add, newSuf);
					}
					free(add);
				} else {
					expand_wildcard(array[i], suffix);
				}
			}
		}
		free(array);
	}
}

/*
 * On parser error, just print the error
 */

void yyerror(const char *message) {
//  fprintf(stderr, "%s", message);
} /* yyerror() */
