; iR3000A.c assembly routines
; zerofrog(@gmail.com)
; ported to nasm by zedr0n

%define REGINFO psxRegs
%define RECLUT psxRecLUT
%define PCOFFSET 0x208				; this must always match that pcx2 displays at startup

%ifdef __APPLE__
	%define psxRegs							_psxRegs
	%define psxRecLUT        		_psxRecLUT
	%define iopRecRecompile  		_iopRecRecompile
	%define iopJITCompile				_iopJITCompile
	%define iopJITCompileInBlock	_iopJITCompileInBlock
	%define iopDispatcherReg		iopDispatcherReg
%else
	%define psxRegs							psxRegs
	%define psxRecLUT        		psxRecLUT
	%define iopRecRecompile  		iopRecRecompile
	%define iopJITCompile				iopJITCompile
	%define iopJITCompileInBlock	iopJITCompileInBlock
	%define iopDispatcherReg		iopDispatcherReg
%endif

extern REGINFO 
extern RECLUT
extern iopRecRecompile

;//////////////////////////////////////////////////////////////////////////
;// The address for all cleared blocks.  It recompiles the current pc and then
;// dispatches to the recompiled block address.

global iopJITCompile
iopJITCompile:

	mov esi, dword [REGINFO + PCOFFSET]
	mov eax, esp												; save stack pointer
	and esp, 0xFFFFFFF0									; align stack
	push eax														; save on stack old stack pointer
	sub esp, 0x8												; 4+8+4=0x10
	push esi
	call iopRecRecompile
	add esp, 4													; pop old param

	add esp, 8
	pop esp															; restore stack

	mov ebx, esi
	shr esi, 16
	mov ecx, dword [RECLUT+esi*4]
	jmp dword [ecx+ebx]

global iopJITCompileInBlock
iopJITCompileInBlock:
	jmp iopJITCompile

;//////////////////////////////////////////////////////////////////////////
;// called when jumping to variable pc address.

global iopDispatcherReg
global _iopDispatcherReg
iopDispatcherReg:
_iopDispatcherReg

	mov eax, dword [REGINFO + PCOFFSET]
	mov ebx, eax
	shr eax, 16
	mov ecx, dword [RECLUT+eax*4]
	jmp dword [ecx+ebx]

