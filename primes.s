/*
 * Copyright (C) 2020 Lucas Ransan <lucas@ransan.tk>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

/* This program uses the sieve of Eratosthenes
   (https://wikipedia.org/wiki/Sieve_of_Eratosthenes)
   to print all the primes up to and including the argument num.

   We use a bit array to represent all the numbers from 0 to num.
   The first bit represents 0, the second 1, the third 2, ...
   A set bit represents a prime number, so after eliminating all
   the non primes, the bit array should look like that:
     001101010001010001010...
*/


/* Length of the buffer for writing to stdout */
.set BUF_LEN, 2048000 # 2 MB


/* Initialized memory */
	.data
arg_err:
	.ascii "Please supply one argument\n"
	.set ae_len, . - arg_err

num_err:
	.ascii "Please supply a valid number > 0\n"
	.set ne_len, . - num_err


/* Uninitialized memory */
	.bss

/* 64 bit unsigned integer we print primes up to */
num:
	.quad 0

/* Square root of num */
sqrt_num:
	.quad 0

/* Address to the sys_mmap'ed bit array */
primes:
	.quad 0

/* The buffer for writing to stdout */
char_buf:
	.fill BUF_LEN



	.globl _start
	.text
_start:
	/* Read argc and jump if it is 2 (program name + number)
	   (%rsp) = argc
	   8(%rsp) = argv[0]
	   16(%rsp) = argv[1]
	*/
	movq	(%rsp), %rbx
	cmpq	$2, %rbx
	je	.argc_good

	/* Write error to stderr */
	movq	$1, %rax # sys_write
	movq	$2, %rdi # fd
	movq	$arg_err, %rsi # buf
	movq	$ae_len, %rdx # count
	syscall

	/* Exit with code 1 */
	movq	$60, %rax # sys_exit
	movq	$1, %rdi # error_code
	syscall


.argc_good:
	/* Read the number for argv[1] with strtoumax */
	movq	16(%rsp), %rdi # str = argv[1]
	xorq	%rsi, %rsi # endptr = null
	movq	$10, %rdx # base
	call	strtoumax
	/* Store the result in num and jump if != 0 */
	movq	%rax, num
	testq	%rax, %rax
	jnz	.number_good
	
	/* Write error to stderr */
	movq	$1, %rax # sys_write
	movq	$2, %rdi # fd
	movq	$num_err, %rsi # buf
	movq	$ne_len, %rdx # count
	syscall

	/* Exit with code 1 */
	movq	$60, %rax # sys_exit
	movq	$1, %rdi # error_code
	syscall


.number_good:
	/* If num == 1, we can jump to the end,
	   because we know 1 isn't prime.
	*/
	cmpq	$1, num
	je	.finish

	/* Allocate memory for num + 1 (0, 1, 2, ..., num) bits,
	   which is num / 8 + 1 bytes.
	*/
	movq	$9, %rax # sys_mmap
	xorq	%rdi, %rdi # addr = null
	movq	num, %rsi
	shrq	$3, %rsi
	incq	%rsi # len = n / 8 + 1
	movq	$3, %rdx # prot = read | write
	movq	$0x22, %r10 # flags = private | anonymous
	movq	$-1, %r8 # fd
	xorq	%r9, %r9 # offset
	syscall
	/* Store the address of the allocated memory in primes and %r15 */
	movq	%rax, primes
	movq	%rax, %r15

	/* Set 2, 3, 5, 7, and all odds as potential primes */
	movq	primes, %rdi
	movb	$0b00110101, (%rdi)
	incq	%rdi # ptr = primes[1]
	movl	$0b01010101, %esi # value
	movq	num, %rdx
	shrq	$3, %rdx # num = num / 8
	call	memset

	/* Calculate the square root of num with the FPU (rounded down) */
	push	num
	fildq	(%rsp)
	fsqrt
	fistpq	(%rsp)
	pop	sqrt_num


	/* We eliminate all non primes by setting
	   the correponding bit to 0 in the bit array.

	   %rbx: counter from 3 to sqrt_num incremented by 2
	*/
	movq	$1, %rbx
.elim_loop:
	addq	$2, %rbx
	cmpq	sqrt_num, %rbx
	ja	.end_elim

	/* If the bit corresponding to the number in the counter
	     primes[%rbx / 8] >> (7 - %rbx % 8)
	   isn't set, we jumpt to the start of the loop (.elim_loop).
	*/
	movq	%rbx, %rax
	shrq	$3, %rax # %rax = %rbx / 8
	movb	(%r15, %rax), %al # %al = primes[%rax]

	movq	%rbx, %rdx
	andb	$0b111, %dl # %dl = %rbx % 8
	movb	$7, %cl
	subb	%dl, %cl # %cl = 7 - %dl

	shrb	%cl, %al # %al >>= %cl
	andb	$1, %al
	jz	.elim_loop


	/* The bit corresponding to %rbx is set, so we eliminate
	   (set to 0) all multiples of %rbx.
	     primes[%r8 * %rbx / 8] &= ~(1 << (7 - (%r8 * %rbx) % 8))
	   We only need to eliminate odds multiples of %rbx,
	   because we didn't set the evens to 1 in the first place.
	     odd * odd = odd
	     _   * _   = even

	   %r8: counter from 3 to num incremented by 2
	*/
	movq	$1, %r8
.inner_loop:
	addq	$2, %r8
	movq	%r8, %rax
	mulq	%rbx # %rax = %r8 * %rbx
	cmpq	num, %rax
	ja	.end_inner

	movq	%rax, %rdx
	shrq	$3, %rdx # %rdx = %rax / 8
	movb	(%r15, %rdx), %r10b # %r10b = primes[%rdx]

	andb	$0b111, %al # %al = %rax % 8
	movb	$7, %cl
	subb	%al, %cl # %cl = 7 - %al

	movb	$1, %r11b
	shlb	%cl, %r11b
	notb	%r11b # %r11b = ~(1 << %cl)

	andb	%r11b, %r10b
	movb	%r10b, (%r15, %rdx) # primes[%rdx] = %r10b & %r11b

	jmp	.inner_loop
.end_inner:

	jmp	.elim_loop
.end_elim:

	/* Now that all the bits corresponding to primes are set to 1,
	   and the others are set to 0, we can start to print!

	   Print "2\n" here, because we don't print even numbers in the loop.
	*/
	movb	$0x32, %dil # '2'
	call	putchar
	movb	$0xA, %dil # '\n'
	call	putchar

	# Print the numbers
	movq	$1, %rbx
.print_loop:
	addq	$2, %rbx
	cmpq	num, %rbx
	ja	.end_print

	movq	%rbx, %rax
	shrq	$3, %rax
	movb	(%r15, %rax), %al

	movq	%rbx, %rdx
	andb	$0b111, %dl
	movb	$7, %cl
	subb	%dl, %cl
	# %cl = 7 - %rdx % 8

	shrb	%cl, %al
	andb	$1, %al
	jz	.print_loop

	xorq	%r12, %r12
	movq	%rbx, %rax
.div_loop:
	# Divide %rax by 10
	movq	%rax, %rdi
	movabsq	$-3689348814741910323, %rdx
	mulq	%rdx
	shrq	$3, %rdx
	leaq	(%rdx, %rdx, 4), %r11
	movq	%rdx, %rax
	addq	%r11, %r11
	subq	%r11, %rdi
	# %rax = %rax / 10
	# %rdi = %rai % 10

	addq	$0x30, %rdi
	push	%rdi
	incq	%r12

	testq	%rax, %rax
	jnz	.div_loop

.putc_loop:
	pop	%rdi
	decq	%r12
	andq	$0xFF, %rdi
	call	putchar

	testq	%r12, %r12
	jnz	.putc_loop

	# Print '\n'
	movb	$0xA, %dil
	call	putchar

	jmp	.print_loop
.end_print:
	movq	stdout, %rdi
	call	fflush

.finish:
	/* Exit with code 0 */
	movq	$60, %rax # sys_exit
	xorq	%rdi, %rdi # error_code
	syscall

# vim: et! ts=8 sts=8 sw=8
