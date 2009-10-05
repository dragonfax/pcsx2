; iR5900.c assembly routines
; ported to nasm by zedr0n

%define REGINFO cpuRegs
%define RECLUT recLUT
%define PCOFFSET 0x2a8				; this must always match that pcx2 displays at startup

%ifdef __APPLE__
	%define cpuRegs						_cpuRegs
	%define recLUT	        	_recLUT
	%define recRecompile  		_recRecompile
	%define JITCompile				_JITCompile
	%define JITCompileInBlock	_JITCompileInBlock
	%define DispatcherReg		_DispatcherReg
%else
	%define cpuRegs						cpuRegs
	%define recLUT	        	recLUT
	%define recRecompile  		recRecompile
	%define JITCompile				JITCompile
	%define JITCompileInBlock	JITCompileInBlock
	%define DispatcherReg		DispatcherReg
%endif

extern REGINFO 
extern RECLUT
extern recRecompile

;//////////////////////////////////////////////////////////////////////////
;// The address for all cleared blocks.  It recompiles the current pc and then
;// dispatches to the recompiled block address.

global JITCompile
JITCompile:

	mov esi, dword [REGINFO + PCOFFSET]
	mov eax, esp												; save stack pointer
	and esp, 0xFFFFFFF0									; align stack
	push eax														; save on stack old stack pointer
	sub esp, 0x8												; 4+8+4=0x10
	push esi
	call recRecompile
	add esp, 4													; pop old param

	add esp, 8
	pop esp															; restore stack

	mov ebx, esi
	shr esi, 16
	mov ecx, dword [RECLUT+esi*4]
	jmp dword [ecx+ebx]

global JITCompileInBlock
JITCompileInBlock:
	jmp JITCompile

;//////////////////////////////////////////////////////////////////////////
;// called when jumping to variable pc address.

global DispatcherReg
DispatcherReg:

	mov eax, dword [REGINFO + PCOFFSET]
	mov ebx, eax
	shr eax, 16
	mov ecx, dword [RECLUT+eax*4]
	jmp dword [ecx+ebx]
