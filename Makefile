# If you add .c/.h pairs, add their names without any extension here
# Try to only modify this line
SOURCE_NAMES = command

# Use GNU compiler
CC = gcc -g
WARNINGS = -Wall -Werror

# Resolve /etc/alternatives symlinks for clarity
LEX = flex
YACC = bison.yacc

SRC_C = $(SOURCE_NAMES:=.c)
SRC_H = $(SOURCE_NAMES:=.h)
SRC_O = $(SOURCE_NAMES:=.o)

all: git shell

lex.yy.o: shell.l y.tab.h
	$(LEX) shell.l
	$(CC) -c lex.yy.c

y.tab.c y.tab.h: shell.y $(SRC_H)
	$(YACC) -d shell.y

y.tab.o: y.tab.c
	$(CC) -c y.tab.c

$(SRC_O) : %.o : %.c $(SRC_H)
	$(CC) $(WARNINGS) -c $<

shell: y.tab.o lex.yy.o $(SRC_O)
	$(CC) -o shell lex.yy.o y.tab.o $(SRC_O) -lfl

# DO NOT MODIFY
git:
	git add *.c *.h *.l *.y Makefile >> .local.git.out || echo
	git commit -a -m "Commit lab 3" >> .local.git.out || echo
	git push origin HEAD:master

clean:
	rm -f lex.yy.c y.tab.c y.tab.h shell *.o
