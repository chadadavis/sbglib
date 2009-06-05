
# Compiling
CC = gcc
# Compiling objects
SFLAGS = -fpic
# Compiling libraries
LIBFLAGS = -shared
# Compiling executables or libraries
LDFLAGS = -lm

# Optimization
CCFLAGS = -O3 -DAVE_INLINE $(SFLAGS)
# Debugging
#CCFLAGS = -O0 -g3 -pg $(SFLAGS)
# Valgrind (doesn't like -pg)
#CCFLAGS = -O0 -g3 $(SFLAGS) 

# Objects
OBJS = \
	clashes.o

BINS = \
	clashes

LIBS = \
	libclashes.so

# Force object files to depend on their headers
%.o: %.c %.h
	$(CC) $(CCFLAGS) -c `basename $@ .o`.c


all: TAGS $(BINS) $(LIBS)


lib: libclashes.so


clashes: clashes.o
	$(CC) $(CCFLAGS) $(LDFLAGS) $@.o -o $@


libclashes.so: $(OBJS)
	ld $(LIBFLAGS) $(LDFLAGS) $(OBJS) -o $@


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
	$(CC) -o /dev/null -Wall -S ${CHK_SOURCES} $(SFLAGS) $(LDFAGS)

