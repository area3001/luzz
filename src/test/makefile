IPATH = /usr/local/sbin
PROG = luzz-gen
OBJS = luzz-gen.o
LIBS = -lmosquitto
CSTD = -std=gnu99

WARN = -Wall -pedantic
CFLAGS += $(CSTD) $(WARN)
LDFLAGS += $(CSTD)

$(PROG): $(OBJS)
	$(CC) $(LDFLAGS) $(OBJS) $(LIBS) -o $@

.c.o:
	$(CC) -c $(CFLAGS) -o $@ $<

install:
	cp $(PROG) $(IPATH)

clean:
	rm -f $(PROG) $(OBJS)
