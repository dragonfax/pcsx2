; iR5900.c assembly routines
; zerofrog(@gmail.com)
; ported to nasm by zedr0n

%ifdef __APPLE__
	%define cpuRegs							_cpuRegs
	%define recRecompile       	_recRecompile
	%define recLUT             	_recLUT
	%define lbase              	_lbase
	%define s_pCurBlock_ltime  	_s_pCurBlock_ltime
	%define Dispatcher					_Dispatcher
	%define DispatcherClear			_DispatcherClear
	%define DispatcherReg				_DispatcherReg
	%ifndef _DEV_BUILD
	%define StartPerfCounter		_StartPerfCounter
	%define StopPerfCounter			_StopPerfCounter
	%else
	%define StartPerfCounter		__StartPerfCounter
	%define StopPerfCounter			__StopPerfCounter
	%endif
%else
	%define cpuRegs							cpuRegs
	%define recRecompile       	recRecompile
	%define recLUT             	recLUT
	%define lbase              	lbase
	%define s_pCurBlock_ltime  	s_pCurBlock_ltime
	%define Dispatcher					Dispatcher
	%define DispatcherClear			DispatcherClear
	%define StartPerfCounter		StartPerfCounter
	%define StopPerfCounter			StopPerfCounter
%endif

extern cpuRegs
extern recRecompile
extern recLUT
extern lbase
extern s_pCurBlock_ltime

%define BLOCKTYPE_STARTPC	4		; startpc offset
%define BLOCKTYPE_DELAYSLOT	1		; if bit set, delay slot

%define BASEBLOCK_SIZE 2 ; in dwords
%define PCOFFSET 0x2a8

%define REG_PC ecx
%define REG_BLOCK esi

global Dispatcher
Dispatcher:
; EDX contains the jump addr to modify
	push edx

;calc PC_GETBLOCK
; ((BASEBLOCK*)(recLUT[((u32)(x)) >> 16] + (sizeof(BASEBLOCK)/4)*((x) & 0xffff)))
	mov eax, dword [cpuRegs + PCOFFSET]
	mov REG_BLOCK, eax
	mov REG_PC, eax
	shr eax, 16   
	and REG_BLOCK, 0xffff
  shl eax, 2
	add eax, dword [recLUT]
	shl REG_BLOCK, 1
	add REG_BLOCK, dword [eax]
	
; check if startpc == cpuRegs.pc
;and ecx, 0x5fffffff // remove higher bits
	cmp REG_PC, dword [REG_BLOCK+BLOCKTYPE_STARTPC]
	je Dispatcher_CheckPtr

; recompile
	push REG_BLOCK
	push REG_PC ; pc
	call recRecompile
	add esp, 4 ; pop old param
	pop REG_BLOCK
Dispatcher_CheckPtr:
	mov REG_BLOCK, dword [REG_BLOCK]

%ifdef _DEBUG
	test REG_BLOCK, REG_BLOCK
	jnz Dispatcher_CallFn
; throw an exception
	int 10
	
Dispatcher_CallFn:
%endif

	and REG_BLOCK, 0x0fffffff
	mov edx, REG_BLOCK
	pop ecx ; x86to mod
	sub edx, ecx
	sub edx, 4
	mov dword [ecx], edx

	jmp REG_BLOCK

global DispatcherClear
DispatcherClear:
; EDX contains the current pc
	mov dword [cpuRegs + PCOFFSET], edx

; calc PC_GETBLOCK
;((BASEBLOCK*)(recLUT[((u32)(x)) >> 16] + (sizeof(BASEBLOCK)/4)*((x) & 0xffff)))
	mov eax, edx
	mov REG_BLOCK, edx
	shr eax, 16
	and REG_BLOCK, 0xffff
	shl eax, 2
	add eax, dword [recLUT]
	shl REG_BLOCK, 1
	add REG_BLOCK, dword [eax]

	cmp edx, dword [REG_BLOCK + 4]
	jne DispatcherClear_Recompile
	
	add esp, 4 ; ignore stack
	mov eax, dword [REG_BLOCK]
	
%ifdef _DEBUG
	test eax, eax
	jnz DispatcherClear_CallFn
; throw an exception
	int 10
	
DispatcherClear_CallFn:
%endif

	and eax, 0x0fffffff
	jmp eax

DispatcherClear_Recompile:
	push REG_BLOCK
	push edx
	call recRecompile
	add esp, 4 ; pop old param
	pop REG_BLOCK
	mov eax, dword [REG_BLOCK]

	pop ecx ; old fnptr

	and eax, 0x0fffffff
	mov byte [ecx], 0xe9 ; jmp32
	mov edx, eax
	sub edx, ecx
	sub edx, 5
	mov dword [ecx+1], edx

	jmp eax


; called when jumping to variable pc address
global DispatcherReg
DispatcherReg:

	;s_pDispatchBlock = PC_GETBLOCK(cpuRegs.pc);
	mov edx, dword [cpuRegs+PCOFFSET]
	mov ecx, edx
	
	shr edx, 14
	and edx, 0xfffffffc
	add edx, [recLUT]
	mov edx, dword [edx]

	mov eax, ecx
	and eax, 0xfffc
	; edx += 2*eax
	shl eax, 1
	add edx, eax
	
; check if startpc == cpuRegs.pc
	mov eax, ecx
;and eax, 0x5fffffff // remove higher bits
	cmp eax, dword [edx+BLOCKTYPE_STARTPC]
	jne DispatcherReg_recomp

	mov eax, dword [edx]

%ifdef _DEBUG
	test eax, eax
	jnz CallFn2
	% throw an exception
	int 10
	
CallFn2:

%endif

	and eax, 0x0fffffff
	jmp eax ; fnptr

DispatcherReg_recomp:
	;sub esp, 8
	mov eax, esp
	and esp, 0xFFFFFFF0			; align stack
	push eax								; save esp
	sub esp, 4							; 4+4+2*4 = 0x10

	push edx								; save pointer
	;mov dword [esp+4], edx
	;mov dword [esp], ecx
	push ecx								; pass startpc
	call recRecompile
	add esp, 4							;	pop old param
	pop edx
	add esp,4
	pop esp									; restore stack

	mov eax, dword [edx]
	and eax, 0x0fffffff
	jmp eax ; fnptr

%ifndef _0_9_3_
global StartPerfCounter
StartPerfCounter:

	push eax
	push ebx
	push ecx

	rdtsc
	mov dword [lbase], eax
	mov dword [lbase + 4], edx

	pop ecx
	pop ebx
	pop eax
	ret

global StopPerfCounter
StopPerfCounter:

	push eax
	push ebx
	push ecx

	rdtsc

	sub eax, dword [lbase]
	sbb edx, dword [lbase + 4]
	mov ecx, s_pCurBlock_ltime
	add eax, dword [ecx]
	adc edx, dword [ecx + 4]
	mov dword [ecx], eax
	mov dword [ecx + 4], edx
	pop ecx
	pop ebx
	pop eax
	ret
%endif
