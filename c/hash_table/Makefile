%.o: %.c
	gcc -c $^

hash_table_test: hash_table.o hash_table_test.o
	gcc $^ -o $@

all: hash_table_test

clean:
	rm -f hash_table_test *.o