#ifndef COMMAND_H
#define COMMAND_H

// simple command data structure
// A simple command specifies everything needed to start a single program.
// It does not include things like IO redirection or pipes

typedef struct {
  // Available space for arguments currently preallocated

  int num_available_arguments;

  // argument list and size

  int num_arguments;
  char **arguments;

} simple_command;

// simple_command functions

simple_command *simple_command_create();
void simple_command_insert_argument(simple_command *s_command, char *argument);

// command data structure
// This data structure should completely describe an entire command one might
// type on the command line, including IO redirection, backgrounding, etc

typedef struct {
  // Available space for simple_commands that has already been allocated

  int num_available_simple_commands;

  // simple_command list and size

  int num_simple_commands;
  simple_command **simple_commands;

  // IO redirection filenames

  char *out_file;
  char *in_file;
  char *err_file;

  int has_output;
  int has_input;
  int has_error;
  int is_background;
  int append_out;
  int append_err;
  int ambiguous;
  int prompt;

} command;

// command functions

command *command_create();

void command_print(command *command);
void command_execute(command *command);
void command_clear(command *command);
int handle_commands(command *command, int i);

void command_insert_simple_command(command *command, simple_command *s_command);

// shell functions

void prompt();

// Declare these global variables. Use "extern" to avoid double-definition.
// They are defined in command.c.

extern command *current_command;
extern simple_command *current_simple_command;

#endif // COMMAND_H
