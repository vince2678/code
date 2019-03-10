%.o: %.cpp
	g++ -c $^

%.a: %.o
	ar rvs $@ $^

bst_example: bst_example.o
	g++ $^ -o $@

all: bst_example

clean:
	rm *.o bst_example *.a -f
