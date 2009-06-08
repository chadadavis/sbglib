
# Compiling
CC = gcc
# Includes and options, for objects and binaries
SFLAGS = -fpic
# Other libs and -L lib paths
LDFLAGS = -lm

# Compiling shared libs
LIBFLAGS = -shared

# Optimization
OFLAGS = -O3 -DAVE_INLINE
# Debugging
#OFLAGS = -O0 -g3 -pg
# Valgrind (doesn't like -pg)
#OFLAGS = -O0 -g3

CPPFLAGS = $(SFLAGS) $(OFLAGS)

# Objects
OBJS = \
	clashes.o \
	pdb.o

BINS = \
	clashes

LIBS = \
	libclashes.so

# Force object files to depend on their headers
%.o: %.c %.h
	$(CC) $(CPPFLAGS) -c `basename $@ .o`.c


all: TAGS $(BINS) $(LIBS)


lib: libclashes.so


clashes: $(OBJS)
	$(CC) $(CPPFLAGS) $(OBJS) $(LDFLAGS) -o $@


libclashes.so: $(OBJS)
	ld $(LIBFLAGS) $(OBJS) $(LDFLAGS) -o $@


TAGS: *.h *.c
	etags --declarations --members $+


test: $(BINS)
	/bin/rm -rf t/test.log
	./clashes t/test.pdb 2 5 t/test.log t/test.comment
	md5sum -c t/test.log.md5


clean:
	rm -f $(OBJS) $(BINS) $(LIBS)


# For flymake-mode in Emacs
check-syntax:
	$(CC) -o /dev/null -Wall -S ${CHK_SOURCES} $(LDFAGS)

