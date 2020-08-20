all: primes

primes: primes.o
	ld -lc -o $@ $<

%.o: %.s Makefile
	as --64 -o $@ $<
