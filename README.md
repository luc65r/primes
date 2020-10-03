# primes


I wanted to learn x86-64 assembly, so I made this program (I have not found
any good name for it) which takes a positive integer as an argument, and
ouputs to stdout all primes integers up to and including the argument.


## Usage

```
$ make
as --64 -o primes.o primes.s
ld -o primes primes.o
$ ./primes 10
2
3
5
7
```


## How it works

The program uses the [sieve of Eratosthenes](https://wikipedia.org/wiki/Sieve_of_Eratosthenes).
Each numbers is represented by a bit in a bit array, which makes accessing a
specific number a bit difficult, because it has to make some bitwise
operations, but it means that the program uses 8 times less memory that if
each number was represented by a byte.

I didn't use any external functions.
I used `sys_mmap` to allocate the bit array, and `sys_write` to write to
stdout and stderr.

I took some time to comment the code (what I don't usually do), so don't
hesitate to take a look!


## Performance

I'm sure compilers can make a better job optimizing code than me,
but it's fast enough.

Example calculating primes up to one hundred million (100,000,000) on a
AMD Ryzen 7 1700 at 4.00 GHz and 16 GB of DDR4-2933 RAM.
```
$ hyperfine './primes 100000000 > /dev/null'
  Time (mean ± σ):     471.6 ms ±   3.1 ms    [User: 467.7 ms, System: 3.1 ms]
  Range (min … max):   467.0 ms … 476.1 ms    10 runs
```

The biggest limitation is the RAM usage, as it allocates `number / 8 + 1`
bytes.
For example, calculating primes up to one hundred billion (100,000,000,000)
will take 12.5 GB of RAM, and if you store the results, the file will take
near 50 GB!


## Possible improvments

* Async output
* Multithreading
* Use the segmented or incremental sieve
