.set BUF_LEN, 2000000 # 2 MB

	.data
arg_err:
	.ascii "Please supply one argument\n"
	.set ae_len, . - arg_err

num_err:
	.ascii "Please supply a valid number > 0\n"
	.set ne_len, . - num_err


	#.bss
num:
	.quad 0
sqrt_num:
	.quad 0

primes:
	.quad 0

char_buf:
	.fill BUF_LEN


	.globl _start
	.text
_start:
	# Read argc
	movq	(%rsp), %rbx
	cmpq	$2, %rbx
	je	.argc_good

	# Print error
	movq	$1, %rax # sys_write
	movq	$2, %rdi # fd 2
	movq	$arg_err, %rsi
	movq	$ae_len, %rdx
	syscall


	# Return with code 1
	movq	$60, %rax
	movq	$1, %rdi
	syscall


.argc_good:
	# Get the number
	movq	16(%rsp), %rdi
	xorq	%rsi, %rsi
	movq	$10, %rdx
	call	strtoumax
	movq	%rax, num

	testq	%rax, %rax
	jnz	.number_good
	
	# Print error
	movq	$1, %rax # sys_write
	movq	$2, %rdi # fd 2
	movq	$num_err, %rsi
	movq	$ne_len, %rdx
	syscall

	# Return with code 1
	movq	$60, %rax
	movq	$1, %rdi
	syscall

.number_good:
	cmpq	$1, num
	je	.finish

	# Allocate n / 8 + 1 bytes of memory
	movq	$9, %rax # sys_mmap
	xorq	%rdi, %rdi # addr = 0
	movq	num, %rsi
	shrq	$3, %rsi
	incq	%rsi # len = n / 8 + 1
	movq	$3, %rdx # prot = read | write
	movq	$0x22, %r10 # flags = private | anonymous
	movq	$-1, %r8 # fd = -1
	xorq	%r9, %r9 # offset = 0
	syscall
	movq	%rax, primes
	movq	%rax, %r15

	movq	primes, %rdi
	movb	$0b00110101, (%rdi)
	incq	%rdi
	movl	$0b01010101, %esi
	movq	num, %rdx
	shrq	$3, %rdx
	call	memset

	push	num
	fildq	(%rsp)
	fsqrt
	fistpq	(%rsp)
	pop	sqrt_num
	# sqrt_num = sqrt(num)

	# Eliminate all non primes
	movq	$1, %rbx
.elim_loop:
	addq	$2, %rbx
	cmpq	sqrt_num, %rbx
	ja	.end_elim

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
	jz	.elim_loop

	movq	$1, %r8
.inner_loop:
	addq	$2, %r8
	movq	%r8, %rax
	mulq	%rbx
	cmpq	num, %rax
	ja	.end_inner

	movq	%rax, %rdx
	shrq	$3, %rdx
	movb	(%r15, %rdx), %r10b

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
	movb	%r10b, (%r15, %rdx)

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


.finish:
	movq	stdout, %rdi
	call	fflush

	# Return with code 0
	movq	$60, %rax
	xorq	%rdi, %rdi
	syscall
