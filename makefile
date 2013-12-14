IPATH = /usr/local/sbin
PROG = luzz
OBJS = luzz.o
LIBS = -lmosquitto
CSTD = -std=gnu99
OPT = -O2
WARN = -Wall -pedantic
CFLAGS += $(CSTD) $(OPT) $(WARN)
LDFLAGS += $(CSTD)

$(PROG): $(OBJS)
	$(CC) $(LDFLAGS) $(OBJS) $(LIBS) -o $@

.c.o:
	$(CC) -c $(CFLAGS) -o $@ $<

install:
	cp $(PROG) $(IPATH)

clean:
	rm -f $(PROG) $(OBJS)
