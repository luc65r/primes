all: primes

primes: primes.o
	ld -lc -o $@ $<

%.o: %.s Makefile
	as --64 -o $@ $<

clean:
	rm -f primes primes.txt

.PHONY: all clean
