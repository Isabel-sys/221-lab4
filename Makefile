CC = gcc 
LDLIBS = -lncurses 
CFLAGS = -no-pie -g

cursor: cursor.s 
	$(CC) $(CFLAGS) $(LDLIBS) -o $@ $^ 

clean: 
	rm cursor
