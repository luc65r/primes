.set NUM, 10

	.data

arg_err:
	.asciz "Please supply one argument\n"

num_err:
	.asciz "Please supply a valid number > 0\n"

	.globl _start
	.text

print_num:
	.asciz "%lu\n"

_start:
	# Read argc
	movq	(%rsp), %rbx
	cmpq	$2, %rbx
	je	.argc_good

	# Print error
	leaq	arg_err, %rdi
	movq	stderr, %rsi
	call	fputs

	# Return with code 1
	movq	$60, %rax
	movq	$1, %rdi
	syscall


.argc_good:
	# Get the number
	movq	16(%rsp), %rdi
	movq	$0, %rsi
	movq	$10, %rdx
	call	strtoumax
	movq	%rax, %r15

	test	%r15, %r15
	jnz	.number_good
	
	# Print error
	leaq	num_err, %rdi
	movq	stderr, %rsi
	call	fputs

	# Return with code 1
	movq	$60, %rax
	movq	$1, %rdi
	syscall

.number_good:
	cmpq	$1, %r15
	je	.finish

	# Allocate n / 8 + 1 bytes of memory
	movq	%r15, %rdi
	shrq	$3, %rdi
	incq	%rdi
	call	malloc
	movq	%rax, %r14

	movb	$0b00110101, (%r14)
	movq	%r14, %rdi
	incq	%rdi
	movl	$0b01010101, %esi
	movq	%r15, %rdx
	shrq	$3, %rdx
	call	memset

	# Eliminate all non primes
	movq	$1, %rbx
.elim_loop:
	addq	$2, %rbx
	cmpq	%r15, %rbx
	ja	.end_elim

	movq	%rbx, %rax
	shrq	$3, %rax
	movb	(%r14, %rax), %al

	movq	%rbx, %rdx
	andb	$0b111, %dl
	movb	$7, %cl
	subb	%dl, %cl
	# %cl = 7 - %rdx % 8

	shrb	%cl, %al
	andb	$1, %al
	jz	.elim_loop

	movq	$1, %r8
.inner_loop:
	addq	$2, %r8
	movq	%r8, %rax
	mulq	%rbx
	cmpq	%r15, %rax
	ja	.end_inner

	movq	%rax, %rdx
	shrq	$3, %rdx
	movb	(%r14, %rdx), %r10b

	movq	%rax, %r9
	andb	$0b111, %r9b
	movb	$7, %cl
	subb	%r9b, %cl
	# %cl = 7 - %rax % 8

	movb	$1, %r11b
	shlb	%cl, %r11b
	notb	%r11b
	# %r11b = ~(1 << (7 - %rax % 8))

	andb	%r11b, %r10b
	movb	%r10b, (%r14, %rdx)

	jmp	.inner_loop
.end_inner:

	jmp	.elim_loop
.end_elim:

	# Print '2'
	movb	$0x32, %dil
	call	putchar
	# Print '\n'
	movb	$0xA, %dil
	call	putchar

	# Print the numbers
	movq	$1, %rbx
.print_loop:
	addq	$2, %rbx
	cmpq	%r15, %rbx
	ja	.end_print

	movq	%rbx, %rax
	shrq	$3, %rax
	movb	(%r14, %rax), %al

	movq	%rbx, %rdx
	andb	$0b111, %dl
	movb	$7, %cl
	subb	%dl, %cl
	# %cl = 7 - %rdx % 8

	shrb	%cl, %al
	andb	$1, %al
	jz	.print_loop

	# Print %rbx
	leaq	print_num, %rdi
	movq	%rbx, %rsi
	call	printf
	jmp	.print_loop

.end_print:

	movq	%r14, %rdi
	call	free

.finish:
	# Return with code 0
	movq	$60, %rax
	movq	$0, %rdi
	syscall
