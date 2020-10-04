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

alloc_err:
	.ascii "Failed to allocate memory\n"
	.set alle_len, . - alloc_err


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
	/* Read the number for argv[1] */
	movq	16(%rsp), %rdi # str = argv[1]
	xorq    %rax, %rax
	xorq	%rbx, %rbx
	movq	$10, %rcx
	
	decq	%rdi
.arg_loop:
	incq	%rdi
	movb	(%rdi), %bl
	testb	%bl, %bl
	jz	.end_arg
        /* Ignore '_' */
	cmpb	$0x5F, %bl
	jz	.arg_loop
        /* Fail if characted is not a digit */
	subb	$0x30, %bl
	js	.number_bad
	cmpb	$10, %bl
	jnc	.number_bad

	mulq	%rcx
	addq	%rbx, %rax
	jmp	.arg_loop
.end_arg:

	/* Store the result in num and jump if != 0 */
	movq	%rax, num
	testq	%rax, %rax
	jnz	.number_good
	
.number_bad:
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
	/* Check if successful (%rax >= 0) */
	testq	%rax, %rax
	jns	.successful_alloc

	/* Write error to stderr */
	movq	$1, %rax # sys_write
	movq	$2, %rdi # fd
	movq	$alloc_err, %rsi # buf
	movq	$alle_len, %rdx # count
	syscall

	/* Exit with code 1 */
	movq	$60, %rax # sys_exit
	movq	$1, %rdi # error_code
	syscall


.successful_alloc:
	/* Store the address of the allocated memory in primes and %r15 */
	movq	%rax, primes
	movq	%rax, %r15

	/* Set 2, 3, 5, and 7 as potential primes */
	movq	primes, %rdi
	movb	$0b00110101, (%rdi)

	movq	num, %rdx
	shrq	$3, %rdx # num = num / 8

	/* If num < 8, we can skip eliminating primes */
	jz      .end_elim

	/* Set all odds as potential primes */
.memset_loop:
	incq	%rdi
	movb	$0b01010101, (%rdi)
	decq    %rdx
	jnz     .memset_loop


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
	   isn't set, we jumpt to the start of the loop (.elim_loop).
	*/
	movq	%rbx, %rax
	shrq	$3, %rax # %rax = %rbx / 8

	/* These are two different ways to check a particular bit.
	   There is no speed difference.
	*/
.if 1
	/* Use the bit test instruction */
	movq	%rbx, %rdx
	andw	$0b111, %dx # %dx = %rbx % 8
	movw	$7, %cx
	subw	%dx, %cx # %cx = 7 - %dx

	btw	%cx, (%r15, %rax)
	jnc	.elim_loop
.else
	/* primes[%rbx / 8] >> (7 - %rbx % 8) */
	movb    (%r15, %rax), %al # %al = primes[%rax]
	movq    %rbx, %rdx
        andb    $0b111, %dl # %dl = %rbx % 8
        movb    $7, %cl
        subb    %dl, %cl # %cl = 7 - %dl

        shrb    %cl, %al # %al >>= %cl
        andb    $1, %al
        jz      .elim_loop
.endif


	/* The bit corresponding to %rbx is set, so we eliminate
	   (set to 0) all multiples of %rbx.
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

	/* These are two ways to set a particular bit to 0.
	   The first way is way slower, despite being simpler.
	*/
.if 0
	andw	$0b111, %ax # %ax = %rax % 8
	movw	$7, %cx
	subw	%ax, %cx # %cx = 7 - %ax

	btrw	%cx, (%r15, %rdx)
.else
	/* primes[%r8 * %rbx / 8] &= ~(1 << (7 - (%r8 * %rbx) % 8)) */
	movb    (%r15, %rdx), %r10b # %r10b = primes[%rdx]

        andb    $0b111, %al # %al = %rax % 8
        movb    $7, %cl
        subb    %al, %cl # %cl = 7 - %al
        movb    $1, %r11b
        shlb    %cl, %r11b
        notb    %r11b # %r11b = ~(1 << %cl)

        andb    %r11b, %r10b
        movb    %r10b, (%r15, %rdx) # primes[%rdx] = %r10b & %r11b
.endif

	jmp	.inner_loop
.end_inner:

	jmp	.elim_loop
.end_elim:

	/* Now that all the bits corresponding to primes are set to 1,
	   and the others are set to 0, we can start to fill the buffer!

	   Fill it with "2\n" here, because we don't deal with
	   even numbers in the loop.
	*/
	xorq	%r13, %r13
	movb	$0x32, char_buf # '2'
	incq	%r13
	movb	$0xA, char_buf(%r13) # '\n'
	incq	%r13

	/* We loop through the odds numbers and check if it is prime.
	   If it is, we can fill the buffer with its decimal representation.

	   %rbx: counter from 3 to num incremented by 2
	*/
	movq	$1, %rbx
.print_loop:
	addq	$2, %rbx
	cmpq	num, %rbx
	ja	.end_print

	/* If the bit corresponding to the number in the counter
	   isn't set, we jumpt to the start of the loop (.print_loop).
	*/
	movq	%rbx, %rax
	shrq	$3, %rax # %rax = %rbx / 8

	/* These are two different ways to check a particular bit.
	   The second way is slightly faster somehow, despite both 
	   ways being no different to the ones earlier.
	*/
.if 0
	/* Use the bit test instruction */
	movq	%rbx, %rdx
	andw	$0b111, %dx # %dx = %rbx % 8
	movw	$7, %cx
	subw	%dx, %cx # %cx = 7 - %dx

	btw	%cx, (%r15, %rax)
	jnc	.print_loop
.else
	/* primes[%rbx / 8] >> (7 - %rbx % 8) */
	movb    (%r15, %rax), %al # %al = primes[%rax]

        movq    %rbx, %rdx
        andb    $0b111, %dl # %dl = %rbx % 8
        movb    $7, %cl
        subb    %dl, %cl # %cl = 7 - %dl

        shrb    %cl, %al # %al >>= %cl
        andb    $1, %al
        jz      .print_loop
.endif

	/* In .div_loop, we divise the number we want to print (%rax) by 10
	   and push the reminder of the division onto the stack until
	   the number is 0.
	   We can't put the reminders directly in the buffer, because the
	   digits would be reversed, so we push them onto the stack and then
	   we pop them in the right order (first in last out).

	   %rax: number to be divised repeatedly by 10
	   %r12: number of digits there are in the stack
	*/
	xorq	%r12, %r12
	movq	%rbx, %rax
.div_loop:
	/* We divise %rax by 10. It is way faster to do it this weird way,
	   beacuse real divisions take a lot of cyles.
	   The code is taken from the gcc output.
	   You can try to understand this here:
	   http://ridiculousfish.com/blog/posts/labor-of-division-episode-i.html
	   (I do not understand it).
	*/
	movq	%rax, %rdi
	movabsq	$-3689348814741910323, %rdx
	mulq	%rdx
	shrq	$3, %rdx
	leaq	(%rdx, %rdx, 4), %r11
	movq	%rdx, %rax # %rax = %rax / 10
	addq	%r11, %r11
	subq	%r11, %rdi # %rdi = %rax % 10

	/* We add 0x30 to the reminder because the ascii code for a digit
	   is 0x30 + digit, and we push it onto the stack.
	*/
	addq	$0x30, %rdi
	push	%rdi
	incq	%r12

	/* Jump back to .div_loop if %rax isn't 0 */
	testq	%rax, %rax
	jnz	.div_loop

	/* If we would overflow the buffer by emptying the stack to it,
	   we write it beforehand.
	*/
	leaq	(%r13, %r12), %rax
	cmpq	$BUF_LEN, %rax
	ja	.write_buf

.fill_loop:
	/* Pop the digit from the stack, and put it in the buffer */
	pop	%rdi
	decq	%r12
	movb	%dil, char_buf(%r13)
	incq	%r13

	/* Continue popping from the stack if there are still digits on it */
	testq	%r12, %r12
	jnz	.fill_loop

	/* We finished putting the digits in the buffer,
	   we can now push '\n' in it.
	*/
	movb	$0xA, char_buf(%r13)
	incq	%r13

	jmp	.print_loop

.write_buf:
	/* Write the buffer contents to stdout */
	movq	$1, %rax # sys_write
	movq	$1, %rdi # fd
	movq	$char_buf, %rsi # buf
	movq	%r13, %rdx # count
	syscall

	/* Reset the position in the buffer */
	xorq	%r13, %r13
	jmp	.fill_loop

.end_print:
	/* Write the rest of the buffer contents to stdout */
	movq	$1, %rax # sys_write
	movq	$1, %rdi # fd
	movq	$char_buf, %rsi # buf
	movq	%r13, %rdx # count
	syscall

	/* Unallocate the memory
	   It is optional, but I think it's a good thing to do.
	*/
	movq	$11, %rax # sys_munmap
	movq	primes, %rdi # addr
	movq	num, %rsi
	shrq	$3, %rsi
	incq	%rsi # len = n / 8 + 1
	syscall

.finish:
	/* Exit with code 0 */
	movq	$60, %rax # sys_exit
	xorq	%rdi, %rdi # error_code
	syscall

# vim: et! ts=8 sts=8 sw=8
