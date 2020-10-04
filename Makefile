all: primes

primes: primes.o
	ld -o $@ $<

%.o: %.s Makefile
	as --64 -o $@ $<

test: primes
	test "$$(./primes 100)" = "$$(echo '2\n3\n5\n7\n11\n13\n17\n19\n23\n29\n31\n37\n41\n43\n47\n53\n59\n61\n67\n71\n73\n79\n83\n89\n97')"
	test $$(./primes 1000000 | wc -l) -eq 78498

bench: primes test
	hyperfine './primes 100000000 > /dev/null'

clean:
	rm -f primes primes.txt

.PHONY: all clean
