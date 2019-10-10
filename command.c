//
// CS252: Shell project
//
// Template file.
// You will need to add more code here to execute the command table.
// You also will probably want to add other files as you add more functionality,
// unless you like having one massive file with thousands of lines of code!
//
// NOTE: You are responsible for fixing any bugs this code may have!
//

#include "command.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <string.h>
#include <signal.h>
#include <fcntl.h>
#include <sys/stat.h>

#include "y.tab.h"

// These global variables are used by shell.y to
// keep track of the current parser state.

command *current_command;
simple_command *current_simple_command;
extern char **environ;
int last_pid = 0;
int in_source = 0;
char *last_arg = NULL;
int last_back = 0;

/*
 * Allocate and initialize a new simple_command.
 * Return a pointer to it.
 */

simple_command *simple_command_create() {
  // Initially allocate space for this many arguments

#define INITIAL_ARUMENT_ARR_SIZE (5)

  simple_command *new_simple_command =
    (simple_command *) malloc(sizeof(simple_command));

  // Create initial space for arguments (may need expansion later)

  new_simple_command->num_available_arguments = INITIAL_ARUMENT_ARR_SIZE;
  new_simple_command->num_arguments = 0;
  new_simple_command->arguments = (char **)
    malloc(new_simple_command->num_available_arguments * sizeof(char *));

  return new_simple_command;
} /* simple_command_create() */

/*
 * Insert an argument into a simple_command.
 * Dynamically expand the argument array if it is too small.
 */

void simple_command_insert_argument(simple_command *s_command, char *argument) {
  if (s_command->num_available_arguments == s_command->num_arguments + 1) {
    // Double the available space

    s_command->num_available_arguments *= 2;
    s_command->arguments =
      (char **) realloc(s_command->arguments,
                        s_command->num_available_arguments * sizeof(char *));
  }

  s_command->arguments[s_command->num_arguments] = argument;

  // NULL argument signals end of arguement list

  s_command->arguments[s_command->num_arguments + 1] = NULL;

  s_command->num_arguments++;
} /* simple_command_insert_argument() */

/*
 * Allocate and initialize a new command. Return a pointer to it.
 */

command *command_create() {
  command *new_command = (command *) malloc(sizeof(command));

  // Create space to point to the first simple command

  new_command->num_available_simple_commands = 1;
  new_command->simple_commands =
    (simple_command **) malloc(new_command->num_available_simple_commands *
                               sizeof(simple_command *));

  new_command->num_simple_commands = 0;
  new_command->out_file = 0;
  new_command->in_file = 0;
  new_command->err_file = 0;
  new_command->is_background = 0;
  new_command->has_output = 0;
  new_command->has_input = 0;
  new_command->has_error = 0;
  new_command->append_out = 0;
  new_command->append_err = 0;
  new_command->ambiguous = 0;
  new_command->prompt = 0;

  return new_command;
} /* command_create() */

/*
 * Insert a simple_command into the command. If we don't have enough
 * space in simple_commands, dynamically allocate more space.
 */

void command_insert_simple_command(command *command,
                                   simple_command *s_command) {
  if (command->num_available_simple_commands == command->num_simple_commands) {
    // double size of simple command list

    command->num_available_simple_commands *= 2;
    command->simple_commands = (simple_command **)
       realloc(command->simple_commands,
               command->num_available_simple_commands *
               sizeof(simple_command *));
  }

  command->simple_commands[command->num_simple_commands] = s_command;
  command->num_simple_commands++;
} /* command_insert_simple_command() */

/*
 * Completely clear a command, freeing all struct members.
 * After running, the command will be completely ready, as if
 * it was newly created.
 */

void command_clear(command *command) {
  for (int i = 0; i < command->num_simple_commands; i++) {
    for (int j = 0; j < command->simple_commands[i]->num_arguments; j++) {
      free(command->simple_commands[i]->arguments[j]);
      command->simple_commands[i]->arguments[j] = NULL;
    }

    free(command->simple_commands[i]->arguments);
    command->simple_commands[i]->arguments = NULL;

    free(command->simple_commands[i]);
    command->simple_commands[i] = NULL;
  }

  int avoid_double_free = 0;
  if (command->out_file == command->err_file) {
    avoid_double_free = 1;
  }

  if (command->out_file) {
    free(command->out_file);
    command->out_file = NULL;
  }

  if (command->in_file) {
    free(command->in_file);
    command->in_file = NULL;
  }

  if (command->err_file && avoid_double_free == 0) {
    free(command->err_file);
    command->err_file = NULL;
  }

  command->num_simple_commands = 0;
  command->out_file = 0;
  command->in_file = 0;
  command->err_file = 0;
  command->ambiguous = 0;
  command->append_out = 0;
  command->append_err = 0;
  command->prompt = 1;
  command->has_output = 0;
  command->has_input = 0;
  command->has_error = 0;
  command->is_background = 0;
} /* command_clear */

/*
 * Print the command table for a command.
 * This displays in a human-readable format, all simple_commands
 * in the command, and other metadata in the command including
 * input redirection and background status.
 */

void command_print(command *command) {
  printf("\n\n");
  printf("              COMMAND TABLE                \n");
  printf("\n");
  printf("  #   Simple Commands\n");
  printf("  --- ----------------------------------------------------------\n");

  for (int i = 0; i < command->num_simple_commands; i++) {
    printf("  %-3d ", i);
    for (int j = 0; j < command->simple_commands[i]->num_arguments; j++) {
      printf("\"%s\" \t", command->simple_commands[i]->arguments[j]);
    }
  }

  printf("\n\n");
  printf("  Output       Input        Error        Background\n");
  printf("  ------------ ------------ ------------ ------------\n");
  printf("  %-12s %-12s %-12s %-12s\n",
         command->out_file ? command->out_file : "default",
         command->in_file ? command->in_file : "default",
         command->err_file ? command->err_file : "default",
         command->is_background ? "YES" : "NO");
  printf("\n\n");
} /* command_print() */

/*
 * Execute the command, setting up all input redirection as specified.
 * Current this is basically a no-op. You must make it work.
 */

void command_execute(command *command) {
  // Don't do anything if there are no simple commands

  if (command->num_simple_commands == 0) {
    prompt();
    return;
  }

  // Print contents of Command data structure

  //  command_print(command);

  int in_std = dup(0);
  int out_std = dup(1);
  int err_std = dup(2);

  int actual_in;
  int actual_err;

  if (command->ambiguous == 1) {
    command_clear(command);
    prompt();
    return;
  }

  if (command->has_input) {
    actual_in = open(command->in_file, O_RDONLY);
  }
  else {
    actual_in = dup(in_std);
  }

  if (command->has_error) {
    int append = 0;
    if (command->append_err == 1) {
      append = O_APPEND;
    }
    actual_err = open(command->err_file, O_CREAT | O_WRONLY | append, S_IRWXU
                                          | S_IRWXU | S_IRWXG);
  }
  else {
    actual_err = dup(err_std);
  }

  // Do nothing if no comands

  if (command->num_simple_commands == 0) {
    prompt();
    return;
  }

  int actual_out;
  int child;
  int i;

  for (i = 0; i < command->num_simple_commands; i++) {
    dup2(actual_in, 0);
    close(actual_in);

    dup2(actual_err, 2);
    close(actual_err);

    int return_value = handle_commands(command, i);

    if (return_value == 1) {
      return;
    }

    if (i == command->num_simple_commands - 1) {
      int final_arg = command->simple_commands[i]->num_arguments;
      last_arg = strdup(command->simple_commands[i]->arguments[final_arg - 1]);

      if (command->has_output) {
        int append = 0;
        if (command->append_out == 1) {
          append = O_APPEND;
        }
        actual_out = open(command->out_file, O_WRONLY | O_CREAT | 
                              append, S_IRWXU | S_IRWXU | S_IRWXG);
      }
      else {
        actual_out = dup(out_std);
      }
    }
    else {
      int arg_pipe[2];
      pipe(arg_pipe);
      actual_out = arg_pipe[1];
      actual_in = arg_pipe[0];
    }
  
    dup2(actual_out, 1);
    close(actual_out);

    child = fork();

    if (child == 0) {
      execvp(command->simple_commands[i]->arguments[0], 
                 command->simple_commands[i]->arguments);
      perror("execvp");
      _exit(1); 
    }
    signal(SIGCHLD, SIG_IGN);
  }
  dup2(in_std, 0);
  dup2(out_std, 1);
  dup2(err_std, 2);
  close(in_std);
  close(out_std);
  close(err_std);

  if (!command->is_background) {
    int wait_holder;
    waitpid(child, &wait_holder, 0);
    last_pid = WEXITSTATUS(wait_holder);
  }
  else {
    last_back = getpid();
  }
  // Clear to prepare for next command

  command_clear(command);

  // Print next prompt

  if (isatty(0)) {
    prompt();
  }
} /* command_execute() */

/*
 * Check for shell commands that need to be handled
 * and return if one is handled
 */

int handle_commands(command *command, int i) {
  if (!strcmp(command->simple_commands[i]->arguments[0], "exit")) {
    printf("Bye!\n");
    exit(1);
  }
  else if (!strcmp(command->simple_commands[i]->arguments[0], "cd")) {
    if (command->simple_commands[i]->arguments[1] != NULL) {
      int retval = chdir(command->simple_commands[i]->arguments[1]);
      if (retval != 0) {
        fprintf(stderr, "cd: can't cd to %s\n", 
                  command->simple_commands[i]->arguments[1]); 
      }
    }
    else {
      chdir(getenv("HOME"));
    }
    command_clear(command);
    prompt();
    return 1;
  }
  else if (!strcmp(command->simple_commands[i]->arguments[0], "unsetenv")) {
    unsetenv(command->simple_commands[i]->arguments[1]);
    command_clear(command);
    prompt();
    return 1;
  }
  else if (!strcmp(command->simple_commands[i]->arguments[0], "setenv")) {
    setenv(command->simple_commands[i]->arguments[1],
             command->simple_commands[i]->arguments[2], 1);
    command_clear(command);
    prompt();
    return 1;
  }
  else if ((!strcmp(command->simple_commands[i]->arguments[0], "printenv"))
             && (command->simple_commands[i]->arguments[1] != NULL)){
    int v = 1;
    char *s = *environ;
    for ( ; s; v++) {
      char *tag = strdup(command->simple_commands[i]->arguments[1]);
      int len = strlen(tag);
      tag[len] = '=';
      tag[len + 1] = '\0';
      if (strstr(s, tag) == s) {
        printf("%s\n", s);
        s = *(environ+v);
      }
    }
    command_clear(command);
    prompt();
    return 1;
  }
  else if (!strcmp(command->simple_commands[i]->arguments[0], "source")) {
    in_source = 1;
    char *file_in = command->simple_commands[i]->arguments[1];
    FILE *file_p = fopen(file_in, "r");
    FILE *reverse = fopen("fileRev", "w+");

    char byte_buffer = fgetc(file_p);
    int i = 0;
    int count = 0;

    fseek(file_p, 0, SEEK_END);
    count = ftell(file_p);

    while (i < count) {
      i++;
      fseek(file_p, -i, SEEK_END);
      fputc(fgetc(file_p), reverse);
    }

    fclose(file_p);
    fclose(reverse);

    reverse = fopen("fileRev", "r");
    byte_buffer = fgetc(reverse);

    do {
      ungetc(byte_buffer, stdin);
      byte_buffer = fgetc(reverse);
    } while (byte_buffer != EOF);

    fclose(reverse);
    remove("fileRev");
    command_clear(command);
    in_source = 0;
    return 1;
  }
  return 0;
} /* handle_commands() */

/*
 * Print the shell prompt
 */

void prompt() {
  if ((isatty(0)) && (in_source == 0)) {
    printf("myshell>");
    fflush(stdout);
  }
} /* prompt() */

/*
 * Start the shell
 */

int main() {
  // initialize the current_command

  current_command = command_create();

  prompt();

  // run the parser

  yyparse();

  return 0;
} /* main() */
