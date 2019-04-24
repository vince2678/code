%.o: %.c
	gcc -c $^

circular_buf_test: circular_buf.o circular_buf_test.o
	gcc $^ -o $@

all: circular_buf_test

clean:
	rm -f circular_buf_test *.o
