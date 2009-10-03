; iR3000A.c assembly routines
; zerofrog(@gmail.com)
; ported to nasm by zedr0n
%ifdef __APPLE__
	%define svudispfntemp       	_svudispfntemp
	%define s_TotalVUCycles       _s_TotalVUCycles
	%define s_callstack           _s_callstack
	%define s_vu1ebp              _s_vu1ebp
	%define s_vu1esp              _s_vu1esp
	%define s_vu1esi              _s_vu1esi
	%define s_vuedi               _s_vuedi
	%define s_vuebx               _s_vuebx
	%define s_saveebx             _s_saveebx
	%define s_saveecx             _s_saveecx
	%define s_saveedx             _s_saveedx
	%define s_saveesi             _s_saveesi
	%define s_saveedi             _s_saveedi
	%define s_saveebp             _s_saveebp
	%define s_writeQ              _s_writeQ
	%define s_writeP              _s_writeP
	%define g_curdebugvu          _g_curdebugvu
	%define SuperVUGetProgram     _SuperVUGetProgram
	%define SuperVUCleanupProgram _SuperVUCleanupProgram
	%define SuperVUExecuteProgram _SuperVUExecuteProgram
	%define SuperVUEndProgram 		_SuperVUEndProgram
	%define g_sseVUMXCSR 					_g_sseVUMXCSR 
	%define g_sseMXCSR 						_g_sseMXCSR
%else
	%define svudispfntemp       	svudispfntemp
	%define s_TotalVUCycles       s_TotalVUCycles
	%define s_callstack           s_callstack
	%define s_vu1ebp              s_vu1ebp
	%define s_vu1esp              s_vu1esp
	%define s_vu1esi              s_vu1esi
	%define s_vuedi               s_vuedi
	%define s_vuebx               s_vuebx
	%define s_saveebx             s_saveebx
	%define s_saveecx             s_saveecx
	%define s_saveedx             s_saveedx
	%define s_saveesi             s_saveesi
	%define s_saveedi             s_saveedi
	%define s_saveebp             s_saveebp
	%define s_writeQ              s_writeQ
	%define s_writeP              s_writeP
	%define g_curdebugvu          g_curdebugvu
	%define SuperVUGetProgram     SuperVUGetProgram
	%define SuperVUCleanupProgram SuperVUCleanupProgram
	%define SuperVUExecuteProgram SuperVUExecuteProgram
	%define SuperVUEndProgram 		SuperVUEndProgram
	%define g_sseVUMXCSR 					g_sseVUMXCSR 
	%define g_sseMXCSR 						g_sseMXCSR
%endif

extern svudispfntemp
extern s_TotalVUCycles
extern s_callstack
extern s_vu1ebp
extern s_vu1esp
extern s_vu1esi
extern s_vuedi
extern s_vuebx
extern s_saveebx
extern s_saveecx
extern s_saveedx
extern s_saveesi
extern s_saveedi
extern s_saveebp
extern s_writeQ
extern s_writeP
extern g_curdebugvu
extern SuperVUGetProgram
extern SuperVUCleanupProgram
extern g_sseVUMXCSR
extern g_sseMXCSR

; SuperVUExecuteProgram(u32 startpc, int vuindex)
global SuperVUExecuteProgram
SuperVUExecuteProgram:
%ifdef __x86_64__
	mov rax, [rsp]
	mov dword [s_TotalVUCycles], 0
	add rsp, 8
	mov [s_callstack], rax
	call SuperVUGetProgram
	push rbp
	push rbx
	push r12
	push r13
	push r14
	push r15
; function arguments
	push rdi
	push rsi
        
%ifdef _DEBUG
	mov [s_vu1esp], rsp
%endif
	
	ldmxcsr [g_sseVUMXCSR]
	mov dword [s_writeQ], 0xffffffff
	mov dword [s_writeP], 0xffffffff
	jmp rax
%else
	mov eax, [esp]
	mov dword  [s_TotalVUCycles], 0
	add esp, 4
	mov [s_callstack], eax
	call SuperVUGetProgram
	mov [s_vu1ebp], ebp
	mov [s_vu1esi], esi
	mov [s_vuedi], edi
	mov [s_vuebx], ebx
%ifdef _DEBUG
	mov [s_vu1esp], esp
%endif
	
	ldmxcsr [g_sseVUMXCSR]
	mov dword [s_writeQ], 0xffffffff
	mov dword [s_writeP], 0xffffffff
	jmp eax
%endif ; __x86_64__


global SuperVUEndProgram
SuperVUEndProgram:
; restore cpu state
	ldmxcsr [g_sseMXCSR]
      
%ifdef __x86_64__
%ifdef _DEBUG
	sub [s_vu1esp], rsp
%endif
        
; function arguments for SuperVUCleanupProgram
	pop rsi
	pop rdi
	
	pop r15
	pop r14
	pop r13
	pop r12
	pop rbx
	pop rbp
%else
	mov ebp, [s_vu1ebp]
	mov esi, [s_vu1esi]
	mov edi, [s_vuedi]
	mov ebx, [s_vuebx]
                
%ifdef _DEBUG
	sub s_vu1esp, esp
%endif
%endif
        
	call SuperVUCleanupProgram
	jmp [s_callstack] ; so returns correctly


global _svudispfn
_svudispfn:
%ifdef __x86_64__
	mov [g_curdebugvu], rax
	push rax
	push rcx
	push rdx
	push rbp
	push rsi
	push rdi
	push rbx
	push r8
	push r9
	push r10
	push r11
	push r12
	push r13
	push r14
	push r15

	call svudispfntemp
	
	pop r15
	pop r14
	pop r13
	pop r12
	pop r11
	pop r10
	pop r9
	pop r8
	pop rbx
	pop rdi
	pop rsi
	pop rbp
	pop rdx
	pop rcx
	pop rax
%else
	mov [g_curdebugvu], eax
	mov [s_saveecx], ecx
	mov [s_saveedx], edx
	mov [s_saveebx], ebx
	mov [s_saveesi], esi
	mov [s_saveedi], edi
	mov [s_saveebp], ebp

	call svudispfntemp
	
	mov ecx, [s_saveecx]
	mov edx, [s_saveedx]
	mov ebx, [s_saveebx]
	mov esi, [s_saveesi]
	mov edi, [s_saveedi]
	mov ebp, [s_saveebp]
%endif
	ret

