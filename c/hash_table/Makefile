%.o: %.c
	gcc -c $^

hash_table_test: hash_table.o hash_table_test.o
	gcc $^ -o $@

verbose: hash_table.o hash_table_test.c
	gcc -DVERBOSE $^ -o hash_table_test

all: hash_table_test

clean:
	rm -f hash_table_test *.o