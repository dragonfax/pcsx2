; ported to nasm by zedr0n

%ifdef __APPLE__
	%define g_pCurrentRoutine		_g_pCurrentRoutine
	%define so_call							_so_call
	%define so_resume 					_so_resume
	%define so_exit							_so_exit
%else
	%define g_pCurrentRoutine		g_pCurrentRoutine
	%define so_call							so_call
	%define so_resume 					so_resume
	%define so_exit							so_exit
%endif

extern g_pCurrentRoutine

%ifdef __APPLE__
	%define yuv2rgb_sse2		_yuv2rgb_sse2_mac
%endif

extern yuv2rgb_temp
extern sse2_tables
extern C_BIAS
extern GCr_COEFF
extern GCb_COEFF
extern RCr_COEFF
extern BCb_COEFF
extern mb8

global yuv2rgb_sse2
yuv2rgb_sse2:
	mov eax, 1
	xor esi, esi
	xor edi, edi

	; Use ecx and edx as base pointers, to allow for Mod/RM form on memOps.
	; This saves 2-3 bytes per instruction where these are used. :)
	mov ecx, yuv2rgb_temp
	mov edx, sse2_tables+64;

	align 16
tworows:
	movq xmm3, qword [mb8+256+esi]
	movq xmm1, qword [mb8+320+esi]
	pxor xmm2, xmm2
	pxor xmm0, xmm0
	; could skip the movq but punpck requires 128-bit alignment
	; for some reason, so two versions would be needed,
	; bloating the function (further)
	punpcklbw xmm2, xmm3
	punpcklbw xmm0, xmm1
	; unfortunately I don't think this will matter despite being
	; technically potentially a little faster, but this is
	; equivalent to an add or sub
	pxor xmm2, [edx+C_BIAS] ; xmm2 <-- 8 x (Cb - 128) << 8
	pxor xmm0, [edx+C_BIAS] ; xmm0 <-- 8 x (Cr - 128) << 8

	movaps xmm1, xmm0
	movaps xmm3, xmm2
	pmulhw xmm1, [edx+GCr_COEFF]
	pmulhw xmm3, [edx+GCb_COEFF]
	pmulhw xmm0, [edx+RCr_COEFF]
	pmulhw xmm2, [edx+BCb_COEFF]

	ret


%ifdef __x86_64__

%define FUNC_OFFSET 0
%define STACK_OFFSET 8
%define RBX_OFFSET 16
%define RBP_OFFSET 24
%define R12_OFFSET 32
%define R13_OFFSET 40
%define R14_OFFSET 48
%define R15_OFFSET 56
%define DATA_OFFSET 64
%define RESTORE_OFFSET 72

global so_call
so_call:
	test dword [rdi+RESTORE_OFFSET], 1
	jnz so_call_RestoreRegs
	mov [rdi+RBP_OFFSET], rbp
	mov [rdi+RBX_OFFSET], rbx
	mov [rdi+R12_OFFSET], r12
	mov [rdi+R13_OFFSET], r13
	mov [rdi+R14_OFFSET], r14
	mov [rdi+R15_OFFSET], r15        
	mov dword [rdi+RESTORE_OFFSET], 1
	jmp so_call_CallFn
so_call_RestoreRegs:
; have to load and save at the same time
	mov rax, [rdi+RBP_OFFSET]
	mov rcx, [rdi+RBX_OFFSET]
	mov rdx, [rdi+R12_OFFSET]
	mov [rdi+RBP_OFFSET], rbp
	mov [rdi+RBX_OFFSET], rbx
	mov [rdi+R12_OFFSET], r12
	mov rbp, rax
	mov rbx, rcx
	mov r12, rdx
	mov rax, [rdi+R13_OFFSET]
	mov rcx, [rdi+R14_OFFSET]
	mov rdx, [rdi+R15_OFFSET]
	mov [rdi+R13_OFFSET], r13
	mov [rdi+R14_OFFSET], r14
	mov [rdi+R15_OFFSET], r15
	mov r13, rax
	mov r14, rcx
	mov r15, rdx        

so_call_CallFn:
	mov [g_pCurrentRoutine], rdi

; swap the stack
	mov rax, [rdi+STACK_OFFSET]
	mov [rdi+STACK_OFFSET], rsp
	mov rsp, rax
	mov rax, [rdi+FUNC_OFFSET]
	mov rdi, [rdi+DATA_OFFSET]

	jmp rax

global so_resume
so_resume:
	mov rdi, [g_pCurrentRoutine]
	mov rax, [rdi+RBP_OFFSET]
	mov rcx, [rdi+RBX_OFFSET]
	mov rdx, [rdi+R12_OFFSET]
	mov [rdi+RBP_OFFSET], rbp
	mov [rdi+RBX_OFFSET], rbx
	mov [rdi+R12_OFFSET], r12
	mov rbp, rax
	mov rbx, rcx
	mov r12, rdx
	mov rax, [rdi+R13_OFFSET]
	mov rcx, [rdi+R14_OFFSET]
	mov rdx, [rdi+R15_OFFSET]
	mov [rdi+R13_OFFSET], r13
	mov [rdi+R14_OFFSET], r14
	mov [rdi+R15_OFFSET], r15
	mov r13, rax
	mov r14, rcx
	mov r15, rdx

; put the return address in pcalladdr
	mov rsi, [rsp]
	mov [rdi], rsi
	add rsp, 8 ; remove the return address

; swap stack pointers
	mov rax, [rdi+STACK_OFFSET]
	mov [rdi+STACK_OFFSET], rsp
	mov rsp, rax
	
	ret

global so_exit
so_exit:
	mov rdi, [g_pCurrentRoutine]
	mov rsp, [rdi+STACK_OFFSET]
	mov rbp, [rdi+RBP_OFFSET]
	mov rbx, [rdi+RBX_OFFSET]
	mov r12, [rdi+R12_OFFSET]
	mov r13, [rdi+R13_OFFSET]
	mov r14, [rdi+R14_OFFSET]
	mov r15, [rdi+R15_OFFSET]
	ret
%else

global so_call
so_call:
	mov eax, dword [esp+4]
	test dword [eax+24], 1
	jnz RestoreRegs
	mov [eax+8], ebx
	mov [eax+12], esi
	mov [eax+16], edi
	mov [eax+20], ebp
	mov dword [eax+24], 1
	jmp CallFn
RestoreRegs:
; have to load and save at the same time
	mov ecx, [eax+8]
	mov edx, [eax+12]
	mov [eax+8], ebx
	mov [eax+12], esi
	mov ebx, ecx
	mov esi, edx
	mov ecx, [eax+16]
	mov edx, [eax+20]
	mov [eax+16], edi
	mov [eax+20], ebp
	mov edi, ecx
	mov ebp, edx

CallFn:
	mov [g_pCurrentRoutine], eax
	mov ecx, esp
	mov esp, [eax+4]
	mov [eax+4], ecx

	jmp dword [eax]

global so_resume
so_resume:
	mov eax, [g_pCurrentRoutine]
	mov ecx, [eax+8]
	mov edx, [eax+12]
	mov [eax+8], ebx
	mov [eax+12], esi
	mov ebx, ecx
	mov esi, edx
	mov ecx, [eax+16]
	mov edx, [eax+20]
	mov [eax+16], edi
	mov [eax+20], ebp
	mov edi, ecx
	mov ebp, edx

	; put the return address in pcalladdr
	mov ecx, [esp]
	mov [eax], ecx
	add esp, 4 ; remove the return address

	; swap stack pointers
	mov ecx, [eax+4]
	mov [eax+4], esp
	mov esp, ecx
	ret

global so_exit
so_exit:
	mov eax, [g_pCurrentRoutine]
	mov esp, [eax+4]
	mov ebx, [eax+8]
	mov esi, [eax+12]
	mov edi, [eax+16]
	mov ebp, [eax+20]
	ret

%endif

