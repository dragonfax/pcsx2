;Pcsx2 - Pc Ps2 Emulator
;  Copyright (C) 2002-2007  Pcsx2 Team
;
;  This program is free software; you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation; either version 2 of the License, or
;  (at your option) any later version.
;
;  This program is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License
;  along with this program; if not, write to the Free Software
;  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
;

; ported to nasm by zedr0n

%ifdef __APPLE__
	%define vifRegs _vifRegs
	%define vifMaskRegs _vifMaskRegs
	%define vifRow _vifRow
	%define s_TempDecompress _s_TempDecompress
%else
	%define vifRegs vifRegs
	%define vifMaskRegs vifMaskRegs
	%define vifRow vifRow
	%define s_TempDecompress s_TempDecompress
%endif

extern vifRegs
extern vifMaskRegs
extern vifRow
        
%ifdef __x86_64__
%define VIF_ESP rsp
%define VIF_SRC	rsi
%define VIF_INC	rcx
%define VIF_DST rdi
%define VIF_SIZE edx
%define VIF_TMPADDR rax
%define VIF_SAVEEBX r8
%define VIF_SAVEEBXd r8d
%else
%define VIF_ESP esp
%define VIF_SRC	esi
%define VIF_INC	ecx
%define VIF_DST edi
%define VIF_SIZE edx
%define VIF_TMPADDR eax
%define VIF_SAVEEBX ebx
%define VIF_SAVEEBXd ebx
%endif

%define XMM_R0			xmm0
%define XMM_R1			xmm1
%define XMM_R2			xmm2
%define XMM_WRITEMASK	xmm3
%define XMM_ROWMASK		xmm4
%define XMM_ROWCOLMASK	xmm5
%define XMM_ROW			xmm6
%define XMM_COL			xmm7

%define XMM_R3			XMM_COL

; writing masks
; UNPACK_WRITE0_Regular r0, CL, DEST_OFFSET, MOVDQA
%macro UNPACK_Write0_Regular 4 
	%4  [VIF_DST+%3], %1;
%endmacro

; UNPACK_Write1_Regular(r0, CL, DEST_OFFSET, MOVDQA) 
%macro UNPACK_Write1_Regular 4
	%4  [VIF_DST], %1
	add VIF_DST, VIF_INC
%endmacro

%define UNPACK_Write0_Mask UNPACK_Write0_Regular
%define UNPACK_Write1_Mask UNPACK_Write1_Regular

; masked write (dest needs to be in edi)
; UNPACK_Write0_WriteMask(r0, CL, DEST_OFFSET, MOVDQA)
%macro UNPACK_Write0_WriteMask 4
	%4 XMM_WRITEMASK,  [VIF_TMPADDR + 64*(%2) + 48]
	pand %1, XMM_WRITEMASK
	pandn XMM_WRITEMASK,  [VIF_DST]
	por %1, XMM_WRITEMASK
	%4  [VIF_DST], %1
	add VIF_DST, 16
%endmacro

; masked write (dest needs to be in edi)
; UNPACK_Write1_WriteMask(r0, CL, DEST_OFFSET, MOVDQA)
%macro UNPACK_Write1_WriteMask 4
	%4 XMM_WRITEMASK,  [VIF_TMPADDR + 64*(0) + 48]
	pand %1, XMM_WRITEMASK
	pandn XMM_WRITEMASK,  [VIF_DST]
	por %1, XMM_WRITEMASK
	%4  [VIF_DST], %1
	add VIF_DST, VIF_INC
%endmacro

; UNPACK_Mask_SSE_0(r0)
%macro UNPACK_Mask_SSE_0 1
	pand %1, XMM_WRITEMASK
	por %1, XMM_ROWCOLMASK
%endmacro

; once a  is uncomprssed, applies masks and saves
; note: modifying XMM_WRITEMASK
; dest = row + write (only when mask=0), otherwise write
; UNPACK_Mask_SSE_1(r0)
%macro UNPACK_Mask_SSE_1 1
	pand %1, XMM_WRITEMASK
	por %1, XMM_ROWCOLMASK
	pand XMM_WRITEMASK, XMM_ROW
	paddd %1, XMM_WRITEMASK
%endmacro

; dest = row + write (only when mask=0), otherwise write
; row = row + write (only when mask = 0), otherwise row
; UNPACK_Mask_SSE_2(r0)
%macro UNPACK_Mask_SSE_2 1
	pand %1, XMM_WRITEMASK
	pand XMM_WRITEMASK, XMM_ROW
	paddd XMM_ROW, %1
	por %1, XMM_ROWCOLMASK
	paddd %1, XMM_WRITEMASK
%endmacro
%define UNPACK_WriteMask_SSE_0 UNPACK_Mask_SSE_0
%define UNPACK_WriteMask_SSE_1 UNPACK_Mask_SSE_1
%define UNPACK_WriteMask_SSE_2 UNPACK_Mask_SSE_2

%macro UNPACK_Regular_SSE_0 1
%endmacro

%macro UNPACK_Regular_SSE_1 1
	paddd %1, XMM_ROW
%endmacro

%macro UNPACK_Regular_SSE_2 1
	paddd %1, XMM_ROW
	movdqa XMM_ROW, %1
%endmacro

; setting up masks
%macro UNPACK_Setup_Mask_SSE 1
	mov VIF_TMPADDR, [vifMaskRegs]
	movdqa XMM_ROWMASK,  [VIF_TMPADDR + 64*(%1) + 16]
	movdqa XMM_ROWCOLMASK,  [VIF_TMPADDR + 64*(%1) + 32]
	movdqa XMM_WRITEMASK,  [VIF_TMPADDR + 64*(%1)]
	pand XMM_ROWMASK, XMM_ROW
	pand XMM_ROWCOLMASK, XMM_COL
	por XMM_ROWCOLMASK, XMM_ROWMASK
%endmacro

;%define UNPACK_Start_Setup_Mask_SSE_0(CL) UNPACK_Setup_Mask_SSE CL
%macro UNPACK_Start_Setup_Mask_SSE_0 1
	UNPACK_Setup_Mask_SSE %1
%endmacro

%macro UNPACK_Start_Setup_Mask_SSE_1 1
	mov VIF_TMPADDR, [vifMaskRegs]
	movdqa XMM_ROWMASK,  [VIF_TMPADDR + 64*(%1) + 16]
	movdqa XMM_ROWCOLMASK,  [VIF_TMPADDR + 64*(%1) + 32]
	pand XMM_ROWMASK, XMM_ROW
	pand XMM_ROWCOLMASK, XMM_COL
	por XMM_ROWCOLMASK, XMM_ROWMASK
%endmacro

;%define UNPACK_Start_Setup_Mask_SSE_2(CL)
%macro UNPACK_Start_Setup_Mask_SSE_2 1
%endmacro

;%define UNPACK_Setup_Mask_SSE_0_1(CL) 
%macro UNPACK_Setup_Mask_SSE_0_1 1
%endmacro

%macro UNPACK_Setup_Mask_SSE_1_1 1
	mov VIF_TMPADDR, [vifMaskRegs]
	movdqa XMM_WRITEMASK,  [VIF_TMPADDR + 64*(0)]
%endmacro

; ignore CL, since vif.cycle.wl == 1
%macro UNPACK_Setup_Mask_SSE_2_1 1
	mov VIF_TMPADDR, [vifMaskRegs] 
	movdqa XMM_ROWMASK,  [VIF_TMPADDR + 64*(0) + 16]
	movdqa XMM_ROWCOLMASK,  [VIF_TMPADDR + 64*(0) + 32]
	movdqa XMM_WRITEMASK,  [VIF_TMPADDR + 64*(0)]
	pand XMM_ROWMASK, XMM_ROW
	pand XMM_ROWCOLMASK, XMM_COL
	por XMM_ROWCOLMASK, XMM_ROWMASK
%endmacro

%define UNPACK_Setup_Mask_SSE_0_0 UNPACK_Setup_Mask_SSE
%define UNPACK_Setup_Mask_SSE_1_0 UNPACK_Setup_Mask_SSE
%define UNPACK_Setup_Mask_SSE_2_0 UNPACK_Setup_Mask_SSE

; write mask always destroys XMM_WRITEMASK, so 0_0 = 1_0
%define UNPACK_Setup_WriteMask_SSE_0_0 UNPACK_Setup_Mask_SSE
%define UNPACK_Setup_WriteMask_SSE_1_0 UNPACK_Setup_Mask_SSE
;%define UNPACK_Setup_WriteMask_SSE_2_0(CL) UNPACK_Setup_Mask_SSE CL
%macro UNPACK_Setup_WriteMask_SSE_2_0 1
	UNPACK_Setup_Mask_SSE %1
%endmacro
%define UNPACK_Setup_WriteMask_SSE_0_1 UNPACK_Setup_Mask_SSE_1_1
%define UNPACK_Setup_WriteMask_SSE_1_1 UNPACK_Setup_Mask_SSE_1_1
%define UNPACK_Setup_WriteMask_SSE_2_1 UNPACK_Setup_Mask_SSE_2_1

%define UNPACK_Start_Setup_WriteMask_SSE_0 UNPACK_Start_Setup_Mask_SSE_1
%define UNPACK_Start_Setup_WriteMask_SSE_1 UNPACK_Start_Setup_Mask_SSE_1
%define UNPACK_Start_Setup_WriteMask_SSE_2 UNPACK_Start_Setup_Mask_SSE_2

%macro UNPACK_Start_Setup_Regular_SSE_0 1
%endmacro
%macro UNPACK_Start_Setup_Regular_SSE_1 1
%endmacro
%macro UNPACK_Start_Setup_Regular_SSE_2 1
%endmacro
%macro UNPACK_Setup_Regular_SSE_0_0 1
%endmacro
%macro UNPACK_Setup_Regular_SSE_1_0 1
%endmacro
%macro UNPACK_Setup_Regular_SSE_2_0 1
%endmacro
%macro UNPACK_Setup_Regular_SSE_0_1 1
%endmacro
%macro UNPACK_Setup_Regular_SSE_1_1 1
%endmacro
%macro UNPACK_Setup_Regular_SSE_2_1 1
%endmacro

%macro UNPACK_INC_DST_0_Regular 1
	add VIF_DST, (16*%1)
%endmacro
%macro UNPACK_INC_DST_1_Regular 1
%endmacro
%macro UNPACK_INC_DST_0_Mask 1
	add VIF_DST, (16*%1)
%endmacro
%macro UNPACK_INC_DST_1_Mask 1
%endmacro
%macro UNPACK_INC_DST_0_WriteMask 1
%endmacro
%macro UNPACK_INC_DST_1_WriteMask 1
%endmacro

; unpacks for 1,2,3,4 elements (V3 uses this directly)
; UNPACK4_SSE(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK4_SSE 4
	UNPACK_Setup_%3_SSE_%4_%2 %1+0
	UNPACK_%3_SSE_%4 XMM_R0
	UNPACK_Write%2_%3 XMM_R0, %1, 0, movdqa
	
	UNPACK_Setup_%3_SSE_%4_%2 %1+1
	UNPACK_%3_SSE_%4 XMM_R1
	UNPACK_Write%2_%3 XMM_R1, %1+1, 16, movdqa
	
	UNPACK_Setup_%3_SSE_%4_%2 %1+2
	UNPACK_%3_SSE_%4 XMM_R2
	UNPACK_Write%2_%3 XMM_R2, %1+2, 32, movdqa
	
	UNPACK_Setup_%3_SSE_%4_%2 %1+3
	UNPACK_%3_SSE_%4 XMM_R3
	UNPACK_Write%2_%3 XMM_R3, %1+3, 48, movdqa
	
	UNPACK_INC_DST_%2_%3 4
%endmacro

; V3 uses this directly
; UNPACK3_SSE(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK3_SSE 4
	UNPACK_Setup_%3_SSE_%4_%2 %1
	UNPACK_%3_SSE_%4 XMM_R0 
	UNPACK_Write%2_%3 XMM_R0, %1, 0, movdqa
	
	UNPACK_Setup_%3_SSE_%4_%2 %1+1
	UNPACK_%3_SSE_%4 XMM_R1
	UNPACK_Write%2_%3 XMM_R1, %1+1, 16, movdqa
	
	UNPACK_Setup_%3_SSE_%4_%2 %1+2
	UNPACK_%3_SSE_%4 XMM_R2
	UNPACK_Write%2_%3 XMM_R2, %1+2, 32, movdqa
	
	UNPACK_INC_DST_%2_%3 3
%endmacro
; UNPACK2_SSE(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK2_SSE 4
	UNPACK_Setup_%3_SSE_%4_%2 %1
	UNPACK_%3_SSE_%4 XMM_R0
	UNPACK_Write%2_%3 XMM_R0, %1, 0, movdqa
	
	UNPACK_Setup_%3_SSE_%4_%2 %1+1
	UNPACK_%3_SSE_%4 XMM_R1
	UNPACK_Write%2_%3 XMM_R1, %1+1, 16, movdqa
	
	UNPACK_INC_DST_%2_%3 2
%endmacro

; UNPACK1_SSE(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK1_SSE 4
	UNPACK_Setup_%3_SSE_%4_%2 %1
	UNPACK_%3_SSE_%4 XMM_R0
	UNPACK_Write%2_%3 XMM_R0, %1, 0, movdqa
	
	UNPACK_INC_DST_%2_%3 1
%endmacro

; S-32
; only when cl==1
; UNPACK_S_32SSE_4x(CL, TOTALCL, MaskType, ModeType, MOVDQA)
%macro UNPACK_S_32SSE_4x 5
	%5 XMM_R3,  [VIF_SRC]
	
	pshufd XMM_R0, XMM_R3, 0
	pshufd XMM_R1, XMM_R3, 0x55
	pshufd XMM_R2, XMM_R3, 0xaa
	pshufd XMM_R3, XMM_R3, 0xff
	
	UNPACK4_SSE %1, %2, %3, %4
	
	add VIF_SRC, 16
%endmacro

%macro UNPACK_S_32SSE_4A 4
	UNPACK_S_32SSE_4x %1, %2,%3,%4 , movdqa
%endmacro
%macro UNPACK_S_32SSE_4 4
	UNPACK_S_32SSE_4x %1,%2,%3,%4, movdqu
%endmacro

; UNPACK_S_32SSE_3x(CL, TOTALCL, MaskType, ModeType, MOVDQA)
%macro UNPACK_S_32SSE_3x 5
	%5 XMM_R2,  [VIF_SRC]
	
	pshufd XMM_R0, XMM_R2, 0
	pshufd XMM_R1, XMM_R2, 0x55
	pshufd XMM_R2, XMM_R2, 0xaa
	
	UNPACK3_SSE %1,%2,%3,%4 

	add VIF_SRC, 12
%endmacro

%macro UNPACK_S_32SSE_3A 4
	UNPACK_S_32SSE_3x %1,%2,%3,%4,movdqa
%endmacro
%macro UNPACK_S_32SSE_3 4
	UNPACK_S_32SSE_3x %1,%2,%3,%4, movdqu 
%endmacro

; UNPACK_S_32SSE_2(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_S_32SSE_2 4
	movq XMM_R1,  [VIF_SRC]
	
	pshufd XMM_R0, XMM_R1, 0
	pshufd XMM_R1, XMM_R1, 0x55
	
	UNPACK2_SSE %1,%2,%3,%4
	
	add VIF_SRC, 8
%endmacro

%define UNPACK_S_32SSE_2A UNPACK_S_32SSE_2

; UNPACK_S_32SSE_1(CL, TOTALCL, MaskType, ModeType) 
%macro UNPACK_S_32SSE_1 4
	movd XMM_R0, dword [VIF_SRC]
	pshufd XMM_R0, XMM_R0, 0
	
	UNPACK1_SSE %1,%2,%3,%4
	
	add VIF_SRC, 4
%endmacro

%define UNPACK_S_32SSE_1A UNPACK_S_32SSE_1

; S-16
; UNPACK_S_16SSE_4(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_S_16SSE_4 4
	movq XMM_R3,  [VIF_SRC]
	punpcklwd XMM_R3, XMM_R3
	UNPACK_RIGHTSHIFT XMM_R3, 16
	
	pshufd XMM_R0, XMM_R3, 0
	pshufd XMM_R1, XMM_R3, 0x55
	pshufd XMM_R2, XMM_R3, 0xaa
	pshufd XMM_R3, XMM_R3, 0xff
	
	UNPACK4_SSE %1,%2,%3,%4
	
	add VIF_SRC, 8
%endmacro

%define UNPACK_S_16SSE_4A UNPACK_S_16SSE_4

; UNPACK_S_16SSE_3(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_S_16SSE_3 4
	movq XMM_R2,  [VIF_SRC]
	punpcklwd XMM_R2, XMM_R2
	UNPACK_RIGHTSHIFT XMM_R2, 16
	
	pshufd XMM_R0, XMM_R2, 0
	pshufd XMM_R1, XMM_R2, 0x55
	pshufd XMM_R2, XMM_R2, 0xaa
	
	UNPACK3_SSE %1,%2,%3,%4

	add VIF_SRC, 6
%endmacro

%define UNPACK_S_16SSE_3A UNPACK_S_16SSE_3

; UNPACK_S_16SSE_2(CL, TOTALCL, MaskType, ModeType) 
%macro UNPACK_S_16SSE_2 4
	movd XMM_R1, dword [VIF_SRC]
	punpcklwd XMM_R1, XMM_R1
	UNPACK_RIGHTSHIFT XMM_R1, 16
	
	pshufd XMM_R0, XMM_R1, 0
	pshufd XMM_R1, XMM_R1, 0x55
	
	UNPACK2_SSE %1,%2,%3,%4
	
	add VIF_SRC, 4
%endmacro

%define UNPACK_S_16SSE_2A UNPACK_S_16SSE_2

; UNPACK_S_16SSE_1(CL, TOTALCL, MaskType, ModeType) 
%macro UNPACK_S_16SSE_1 4
	movd XMM_R0, dword [VIF_SRC]
	punpcklwd XMM_R0, XMM_R0
	UNPACK_RIGHTSHIFT XMM_R0, 16
	pshufd XMM_R0, XMM_R0, 0
	
	UNPACK1_SSE %1,%2,%3,%4
	
	add VIF_SRC, 2
%endmacro

%define UNPACK_S_16SSE_1A UNPACK_S_16SSE_1

; S-8
; UNPACK_S_8SSE_4(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_S_8SSE_4 4
	movd XMM_R3, dword [VIF_SRC]
	punpcklbw XMM_R3, XMM_R3
	punpcklwd XMM_R3, XMM_R3
	UNPACK_RIGHTSHIFT XMM_R3, 24
	
	pshufd XMM_R0, XMM_R3, 0
	pshufd XMM_R1, XMM_R3, 0x55
	pshufd XMM_R2, XMM_R3, 0xaa
	pshufd XMM_R3, XMM_R3, 0xff
	
	UNPACK4_SSE %1,%2,%3,%4

	add VIF_SRC, 4
%endmacro

%define UNPACK_S_8SSE_4A UNPACK_S_8SSE_4

; UNPACK_S_8SSE_3(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_S_8SSE_3 4
	movd XMM_R2, dword [VIF_SRC]
	punpcklbw XMM_R2, XMM_R2
	punpcklwd XMM_R2, XMM_R2
	UNPACK_RIGHTSHIFT XMM_R2, 24
	
	pshufd XMM_R0, XMM_R2, 0
	pshufd XMM_R1, XMM_R2, 0x55
	pshufd XMM_R2, XMM_R2, 0xaa
	
	UNPACK3_SSE %1,%2,%3,%4
	
	add VIF_SRC, 3
%endmacro

%define UNPACK_S_8SSE_3A UNPACK_S_8SSE_3

; UNPACK_S_8SSE_2(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_S_8SSE_2 4
	movd XMM_R1, dword [VIF_SRC]
	punpcklbw XMM_R1, XMM_R1
	punpcklwd XMM_R1, XMM_R1
	UNPACK_RIGHTSHIFT XMM_R1, 24
	
	pshufd XMM_R0, XMM_R1, 0
	pshufd XMM_R1, XMM_R1, 0x55
	
	UNPACK2_SSE %1,%2,%3,%4
	
	add VIF_SRC, 2
%endmacro

%define UNPACK_S_8SSE_2A UNPACK_S_8SSE_2

; UNPACK_S_8SSE_1(CL, TOTALCL, MaskType, ModeType) 
%macro UNPACK_S_8SSE_1 4
	movd XMM_R0, dword [VIF_SRC]
	punpcklbw XMM_R0, XMM_R0
	punpcklwd XMM_R0, XMM_R0
	UNPACK_RIGHTSHIFT XMM_R0, 24
	pshufd XMM_R0, XMM_R0, 0
	
	UNPACK1_SSE %1,%2,%3,%4
	
	inc VIF_SRC
%endmacro

%define UNPACK_S_8SSE_1A UNPACK_S_8SSE_1

; V2-32
; UNPACK_V2_32SSE_4A(CL, TOTALCL, MaskType, ModeType) 
%macro UNPACK_V2_32SSE_4A 4
	MOVDQA XMM_R0,   [VIF_SRC]
	MOVDQA XMM_R2,   [VIF_SRC+16]
	
	pshufd XMM_R1, XMM_R0, 0xee
	pshufd XMM_R3, XMM_R2, 0xee
	
	UNPACK4_SSE %1,%2,%3,%4
	
	add VIF_SRC, 32
%endmacro

; UNPACK_V2_32SSE_4(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V2_32SSE_4 4
	movq XMM_R0,  [VIF_SRC]
	movq XMM_R1,  [VIF_SRC+8]
	movq XMM_R2,  [VIF_SRC+16]
	movq XMM_R3,  [VIF_SRC+24]

	UNPACK4_SSE %1,%2,%3,%4
	
	add VIF_SRC, 32
%endmacro

; UNPACK_V2_32SSE_3A(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V2_32SSE_3A 4
	MOVDQA XMM_R0,  [VIF_SRC]
	movq XMM_R2,  [VIF_SRC+16]
	pshufd XMM_R1, XMM_R0, 0xee
	
	UNPACK3_SSE %1, %2, %3,%4
	
	add VIF_SRC, 24
%endmacro

; UNPACK_V2_32SSE_3(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V2_32SSE_3 4
	movq XMM_R0,  [VIF_SRC]
	movq XMM_R1,  [VIF_SRC+8]
	movq XMM_R2,  [VIF_SRC+16]
	
	UNPACK3_SSE %1,%2,%3,%4
	
	add VIF_SRC, 24
%endmacro
	
; UNPACK_V2_32SSE_2(CL, TOTALCL, MaskType, ModeType) 
%macro UNPACK_V2_32SSE_2 4
	movq XMM_R0,  [VIF_SRC]
	movq XMM_R1,  [VIF_SRC+8]
	
	UNPACK2_SSE %1,%2,%3,%4
	
	add VIF_SRC, 16
%endmacro

%define UNPACK_V2_32SSE_2A UNPACK_V2_32SSE_2

; UNPACK_V2_32SSE_1(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V2_32SSE_1 4
	movq XMM_R0,  [VIF_SRC]
	
	UNPACK1_SSE %1,%2,%3,%4
	
	add VIF_SRC, 8
%endmacro

%define UNPACK_V2_32SSE_1A UNPACK_V2_32SSE_1

; V2-16
; due to lemmings, have to copy lower  to the upper qword of every reg
; UNPACK_V2_16SSE_4A(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V2_16SSE_4A 4
	punpcklwd XMM_R0,  [VIF_SRC]
	punpckhwd XMM_R2,  [VIF_SRC]
	
	UNPACK_RIGHTSHIFT XMM_R0, 16
	UNPACK_RIGHTSHIFT XMM_R2, 16
	
	punpckhqdq XMM_R1, XMM_R0
	punpckhqdq XMM_R3, XMM_R2
	
	punpcklqdq XMM_R0, XMM_R0
	punpcklqdq XMM_R2, XMM_R2
	punpckhqdq XMM_R1, XMM_R1
	punpckhqdq XMM_R3, XMM_R3
	
	UNPACK4_SSE %1,%2,%3,%4
	add VIF_SRC, 16
%endmacro

;%define UNPACK_V2_16SSE_4(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V2_16SSE_4 4
	movdqu XMM_R0,   [VIF_SRC]
	
	punpckhwd XMM_R2, XMM_R0
	punpcklwd XMM_R0, XMM_R0
	
	UNPACK_RIGHTSHIFT XMM_R0, 16
	UNPACK_RIGHTSHIFT XMM_R2, 16
	
	punpckhqdq XMM_R1, XMM_R0
	punpckhqdq XMM_R3, XMM_R2
	
	punpcklqdq XMM_R0, XMM_R0
	punpcklqdq XMM_R2, XMM_R2
	punpckhqdq XMM_R1, XMM_R1
	punpckhqdq XMM_R3, XMM_R3
	
	UNPACK4_SSE %1,%2,%3,%4
	
	add VIF_SRC, 16
%endmacro

; UNPACK_V2_16SSE_3A(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V2_16SSE_3A 4
	punpcklwd XMM_R0,  [VIF_SRC]
	punpckhwd XMM_R2,  [VIF_SRC]
	
	UNPACK_RIGHTSHIFT XMM_R0, 16
	UNPACK_RIGHTSHIFT XMM_R2, 16
	
	punpckhqdq XMM_R1, XMM_R0
	
	punpcklqdq XMM_R0, XMM_R0
	punpcklqdq XMM_R2, XMM_R2
	punpckhqdq XMM_R1, XMM_R1
	
	UNPACK3_SSE %1,%2,%3,%4

	add VIF_SRC, 12
%endmacro

; UNPACK_V2_16SSE_3(CL, TOTALCL, MaskType, ModeType) 
%macro UNPACK_V2_16SSE_3 4
	movdqu XMM_R0,  [VIF_SRC]
	
	punpckhwd XMM_R2, XMM_R0
	punpcklwd XMM_R0, XMM_R0
	
	UNPACK_RIGHTSHIFT XMM_R0, 16
	UNPACK_RIGHTSHIFT XMM_R2, 16
	
	punpckhqdq XMM_R1, XMM_R0
	
	punpcklqdq XMM_R0, XMM_R0
	punpcklqdq XMM_R2, XMM_R2
	punpckhqdq XMM_R1, XMM_R1
	
	UNPACK3_SSE %1,%2,%3,%4
	
	add VIF_SRC, 12
%endmacro

; UNPACK_V2_16SSE_2A(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V2_16SSE_2A 4
	punpcklwd XMM_R0,  [VIF_SRC]
	UNPACK_RIGHTSHIFT XMM_R0, 16
	
	punpckhqdq XMM_R1, XMM_R0
	
	punpcklqdq XMM_R0, XMM_R0
	punpckhqdq XMM_R1, XMM_R1
	
	UNPACK2_SSE %1,%2,%3,%4
	
	add VIF_SRC, 8
%endmacro

; UNPACK_V2_16SSE_2(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V2_16SSE_2 4
	movq XMM_R0,  [VIF_SRC]
	punpcklwd XMM_R0, XMM_R0
	UNPACK_RIGHTSHIFT XMM_R0, 16
	
	punpckhqdq XMM_R1, XMM_R0
	
	punpcklqdq XMM_R0, XMM_R0
	punpckhqdq XMM_R1, XMM_R1
	
	UNPACK2_SSE %1,%2,%3,%4
	
	add VIF_SRC, 8
%endmacro 

; UNPACK_V2_16SSE_1A(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V2_16SSE_1A 4
	punpcklwd XMM_R0, [VIF_SRC]
	UNPACK_RIGHTSHIFT XMM_R0, 16
	punpcklqdq XMM_R0, XMM_R0
	
	UNPACK1_SSE %1, %2,%3,%4
	
	add VIF_SRC, 4
%endmacro

;UNPACK_V2_16SSE_1(CL, TOTALCL, MaskType, ModeType) 
%macro UNPACK_V2_16SSE_1 4
	movd XMM_R0, dword [VIF_SRC]
	punpcklwd XMM_R0, XMM_R0
	UNPACK_RIGHTSHIFT XMM_R0, 16
	punpcklqdq XMM_R0, XMM_R0
	
	UNPACK1_SSE %1,%2,%3,%4
	
	add VIF_SRC, 4
%endmacro
; V2-8
; and1 streetball needs to copy lower  to the upper qword of every reg
; UNPACK_V2_8SSE_4(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V2_8SSE_4 4
	movq XMM_R0,  [VIF_SRC]
	
	punpcklbw XMM_R0, XMM_R0
	punpckhwd XMM_R2, XMM_R0
	punpcklwd XMM_R0, XMM_R0
	
	UNPACK_RIGHTSHIFT XMM_R0, 24
	UNPACK_RIGHTSHIFT XMM_R2, 24
	
	punpckhqdq XMM_R1, XMM_R0
	punpckhqdq XMM_R3, XMM_R2
	
	punpcklqdq XMM_R0, XMM_R0
	punpcklqdq XMM_R2, XMM_R2
	punpckhqdq XMM_R1, XMM_R1
	punpckhqdq XMM_R3, XMM_R3
	
	UNPACK4_SSE %1,%2,%3,%4
	
	add VIF_SRC, 8
%endmacro

%define UNPACK_V2_8SSE_4A UNPACK_V2_8SSE_4

; UNPACK_V2_8SSE_3(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V2_8SSE_3 4
	movq XMM_R0,  [VIF_SRC]
	
	punpcklbw XMM_R0, XMM_R0
	punpckhwd XMM_R2, XMM_R0
	punpcklwd XMM_R0, XMM_R0
	
	UNPACK_RIGHTSHIFT XMM_R0, 24
	UNPACK_RIGHTSHIFT XMM_R2, 24
	
	punpckhqdq XMM_R1, XMM_R0
	
	punpcklqdq XMM_R0, XMM_R0
	punpcklqdq XMM_R2, XMM_R2
	punpckhqdq XMM_R1, XMM_R1
	
	UNPACK3_SSE %1,%2,%3,%4
	
	add VIF_SRC, 6
%endmacro

%define UNPACK_V2_8SSE_3A UNPACK_V2_8SSE_3

; UNPACK_V2_8SSE_2(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V2_8SSE_2 4
	movd XMM_R0, dword [VIF_SRC]
	punpcklbw XMM_R0, XMM_R0
	punpcklwd XMM_R0, XMM_R0
	UNPACK_RIGHTSHIFT XMM_R0, 24
	
	punpckhqdq XMM_R1, XMM_R0
	
	punpcklqdq XMM_R0, XMM_R0
	punpckhqdq XMM_R1, XMM_R1
	
	UNPACK2_SSE %1,%2,%3,%4
	
	add VIF_SRC, 4
%endmacro

%define UNPACK_V2_8SSE_2A UNPACK_V2_8SSE_2

; UNPACK_V2_8SSE_1(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V2_8SSE_1 4
	movd XMM_R0, dword [VIF_SRC]
	punpcklbw XMM_R0, XMM_R0
	punpcklwd XMM_R0, XMM_R0
	UNPACK_RIGHTSHIFT XMM_R0, 24
	punpcklqdq XMM_R0, XMM_R0
	
	UNPACK1_SSE %1,%2,%3,%4
	
	add VIF_SRC, 2
%endmacro

%define UNPACK_V2_8SSE_1A UNPACK_V2_8SSE_1

; V3-32
; midnight club 2 crashes because reading a qw at +36 is out of bounds
; UNPACK_V3_32SSE_4x(CL, TOTALCL, MaskType, ModeType, MOVDQA)
%macro UNPACK_V3_32SSE_4x 5
	%5 XMM_R0,  [VIF_SRC]
	movdqu XMM_R1,  [VIF_SRC+12]
	
	UNPACK_Setup_%3_SSE_%4_%2 %1+0
	UNPACK_%3_SSE_%4 XMM_R0
	UNPACK_Write%2_%3 XMM_R0, %1, 0, %5
	
	UNPACK_Setup_%3_SSE_%4_%2 %1+1
	UNPACK_%3_SSE_%4 XMM_R1
	UNPACK_Write%2_%3 XMM_R1, %1+1, 16, %5
	
  %5 XMM_R3,  [VIF_SRC+32]
	movdqu XMM_R2,  [VIF_SRC+24]
	psrldq XMM_R3, 4
	
	UNPACK_Setup_%3_SSE_%4_%2 %1+2
	UNPACK_%3_SSE_%4 XMM_R2
	UNPACK_Write%2_%3 XMM_R2, %1, 32, %5
	
	UNPACK_Setup_%3_SSE_%4_%2 %1+3
	UNPACK_%3_SSE_%4 XMM_R3
	UNPACK_Write%2_%3 XMM_R3, %1+3, 48, %5
	
	UNPACK_INC_DST_%2_%3 4

	add VIF_SRC, 48

%endmacro

%macro UNPACK_V3_32SSE_4A 4
	UNPACK_V3_32SSE_4x %1,%2,%3,%4, movdqa
%endmacro
%macro UNPACK_V3_32SSE_4 4 
	UNPACK_V3_32SSE_4x %1,%2,%3,%4, movdqu
%endmacro

; UNPACK_V3_32SSE_3x(CL, TOTALCL, MaskType, ModeType, MOVDQA)
%macro UNPACK_V3_32SSE_3x 5
	%5 XMM_R0,  [VIF_SRC]
	movdqu XMM_R1,  [VIF_SRC+12]
	
	UNPACK_Setup_%3_SSE_%4_%2 %1
	UNPACK_%3_SSE_%4 XMM_R0
	UNPACK_Write%2_%3 XMM_R0, %1, 0, %5
	
	UNPACK_Setup_%3_SSE_%4_%2 %1+1
	UNPACK_%3_SSE_%4 XMM_R1
	UNPACK_Write%2_%3 XMM_R1, %1+1, 16, %5
	
	movdqu XMM_R2,   [VIF_SRC+24]
	
	UNPACK_Setup_%3_SSE_%4_%2 %1+2
	UNPACK_%3_SSE_%4 XMM_R2
	UNPACK_Write%2_%3 XMM_R2, %1+2, 32, %5
	
	UNPACK_INC_DST_%2_%3 3
	
	add VIF_SRC, 36
%endmacro

%macro UNPACK_V3_32SSE_3A 4
	UNPACK_V3_32SSE_3x %1,%2,%3,%4, movdqa
%endmacro
%macro UNPACK_V3_32SSE_3 4
	UNPACK_V3_32SSE_3x %1,%2,%3,%4, movdqu
%endmacro

; UNPACK_V3_32SSE_2x(CL, TOTALCL, MaskType, ModeType, MOVDQA)
%macro UNPACK_V3_32SSE_2x 5
	%5 XMM_R0,   [VIF_SRC]
	movdqu XMM_R1,  [VIF_SRC+12]
	
	UNPACK2_SSE %1,%2,%3,%4
	
	add VIF_SRC, 24
%endmacro

%macro UNPACK_V3_32SSE_2A 4
	UNPACK_V3_32SSE_2x %1,%2,%3,%4, movdqa
%endmacro
%macro UNPACK_V3_32SSE_2 4
	UNPACK_V3_32SSE_2x %1,%2,%3,%4, movdqu
%endmacro

;  UNPACK_V3_32SSE_1x(CL, TOTALCL, MaskType, ModeType, MOVDQA)
%macro UNPACK_V3_32SSE_1x 5
	%5 XMM_R0,  [VIF_SRC]
	
	UNPACK1_SSE %1,%2,%3,%4
	
	add VIF_SRC, 12
%endmacro

%macro UNPACK_V3_32SSE_1A 4
	UNPACK_V3_32SSE_1x %1,%2,%3,%4, movdqa
%endmacro
%macro UNPACK_V3_32SSE_1 4
	UNPACK_V3_32SSE_1x %1,%2,%3,%4, movdqu
%endmacro

; V3-16
; UNPACK_V3_16SSE_4(CL, TOTALCL, MaskType, ModeType) 
%macro UNPACK_V3_16SSE_4 4
	movq XMM_R0,  [VIF_SRC]
	movq XMM_R1,  [VIF_SRC+6]
	
	punpcklwd XMM_R0, XMM_R0
	movq XMM_R2,  [VIF_SRC+12]
	punpcklwd XMM_R1, XMM_R1
	UNPACK_RIGHTSHIFT XMM_R0, 16
	movq XMM_R3,  [VIF_SRC+18]
	UNPACK_RIGHTSHIFT XMM_R1, 16
	punpcklwd XMM_R2, XMM_R2
	punpcklwd XMM_R3, XMM_R3
	
	UNPACK_RIGHTSHIFT XMM_R2, 16
	UNPACK_RIGHTSHIFT XMM_R3, 16
	
	UNPACK4_SSE %1,%2,%3,%4

	add VIF_SRC, 24
%endmacro

%define UNPACK_V3_16SSE_4A UNPACK_V3_16SSE_4

; UNPACK_V3_16SSE_3(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V3_16SSE_3 4
	movq XMM_R0,  [VIF_SRC]
	movq XMM_R1,  [VIF_SRC+6]
	
	punpcklwd XMM_R0, XMM_R0
	movq XMM_R2,  [VIF_SRC+12]
	punpcklwd XMM_R1, XMM_R1
	UNPACK_RIGHTSHIFT XMM_R0, 16
	punpcklwd XMM_R2, XMM_R2
	
	UNPACK_RIGHTSHIFT XMM_R1, 16
	UNPACK_RIGHTSHIFT XMM_R2, 16
	
	UNPACK3_SSE %1,%2,%3,%4
	
	add VIF_SRC, 18
%endmacro

%define UNPACK_V3_16SSE_3A UNPACK_V3_16SSE_3

; UNPACK_V3_16SSE_2(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V3_16SSE_2 4
	movq XMM_R0,  [VIF_SRC]
	movq XMM_R1,  [VIF_SRC+6]
	
	punpcklwd XMM_R0, XMM_R0
	punpcklwd XMM_R1, XMM_R1
	
	UNPACK_RIGHTSHIFT XMM_R0, 16
	UNPACK_RIGHTSHIFT XMM_R1, 16
	
	UNPACK2_SSE %1,%2,%3,%4
	
	add VIF_SRC, 12
%endmacro

%define UNPACK_V3_16SSE_2A UNPACK_V3_16SSE_2

; UNPACK_V3_16SSE_1(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V3_16SSE_1 4
	movq XMM_R0,  [VIF_SRC]
	punpcklwd XMM_R0, XMM_R0
	UNPACK_RIGHTSHIFT XMM_R0, 16
	
	UNPACK1_SSE %1,%2,%3,%4
	
	add VIF_SRC, 6
%endmacro

%define UNPACK_V3_16SSE_1A UNPACK_V3_16SSE_1

; V3-8
; UNPACK_V3_8SSE_4(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V3_8SSE_4 4
	movq XMM_R1,  [VIF_SRC]
	movq XMM_R3,  [VIF_SRC+6]
	
	punpcklbw XMM_R1, XMM_R1
	punpcklbw XMM_R3, XMM_R3
	punpcklwd XMM_R0, XMM_R1
	psrldq XMM_R1, 6
	punpcklwd XMM_R2, XMM_R3
	psrldq XMM_R3, 6
	punpcklwd XMM_R1, XMM_R1
	UNPACK_RIGHTSHIFT XMM_R0, 24
	punpcklwd XMM_R3, XMM_R3
	
	UNPACK_RIGHTSHIFT XMM_R2, 24
	UNPACK_RIGHTSHIFT XMM_R1, 24
	UNPACK_RIGHTSHIFT XMM_R3, 24
	
	UNPACK4_SSE %1,%2,%3,%4
	
	add VIF_SRC, 12
%endmacro

%define UNPACK_V3_8SSE_4A UNPACK_V3_8SSE_4

; UNPACK_V3_8SSE_3(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V3_8SSE_3 4
	movd XMM_R0, dword [VIF_SRC]
	movd XMM_R1, dword [VIF_SRC+3]
	
	punpcklbw XMM_R0, XMM_R0
	movd XMM_R2, dword [VIF_SRC+6]
	punpcklbw XMM_R1, XMM_R1
	punpcklwd XMM_R0, XMM_R0
	punpcklbw XMM_R2, XMM_R2
	
	punpcklwd XMM_R1, XMM_R1
	punpcklwd XMM_R2, XMM_R2
	
	UNPACK_RIGHTSHIFT XMM_R0, 24
	UNPACK_RIGHTSHIFT XMM_R1, 24
	UNPACK_RIGHTSHIFT XMM_R2, 24
	
	UNPACK3_SSE %1,%2,%3,%4
	
	add VIF_SRC, 9 
%endmacro 

%define UNPACK_V3_8SSE_3A UNPACK_V3_8SSE_3

; UNPACK_V3_8SSE_2(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V3_8SSE_2 4
	movd XMM_R0, dword [VIF_SRC]
	movd XMM_R1, dword [VIF_SRC+3]
	
	punpcklbw XMM_R0, XMM_R0
	punpcklbw XMM_R1, XMM_R1
	
	punpcklwd XMM_R0, XMM_R0
	punpcklwd XMM_R1, XMM_R1
	
	UNPACK_RIGHTSHIFT XMM_R0, 24
	UNPACK_RIGHTSHIFT XMM_R1, 24
	
	UNPACK2_SSE %1,%2,%3,%4
	
	add VIF_SRC, 6
%endmacro

%define UNPACK_V3_8SSE_2A UNPACK_V3_8SSE_2

; UNPACK_V3_8SSE_1(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V3_8SSE_1 4
	movd XMM_R0, dword [VIF_SRC]
	punpcklbw XMM_R0, XMM_R0
	punpcklwd XMM_R0, XMM_R0
	UNPACK_RIGHTSHIFT XMM_R0, 24

	UNPACK1_SSE %1,%2,%3,%4

	add VIF_SRC, 3
%endmacro

%define UNPACK_V3_8SSE_1A UNPACK_V3_8SSE_1

; V4-32
; UNPACK_V4_32SSE_4A(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V4_32SSE_4A 4
	movdqa XMM_R0,  [VIF_SRC]
	movdqa XMM_R1,  [VIF_SRC+16]
	movdqa XMM_R2,  [VIF_SRC+32]
	movdqa XMM_R3,  [VIF_SRC+48]
	
	UNPACK4_SSE %1,%2,%3,%4 
	
	add VIF_SRC, 64
%endmacro

; UNPACK_V4_32SSE_4(CL, TOTALCL, MaskType, ModeType) 
%macro UNPACK_V4_32SSE_4 4
	movdqu XMM_R0,  [VIF_SRC]
	movdqu XMM_R1,  [VIF_SRC+16]
	movdqu XMM_R2,  [VIF_SRC+32]
	movdqu XMM_R3,  [VIF_SRC+48]
	
	UNPACK4_SSE %1,%2,%3,%4
	
	add VIF_SRC, 64
%endmacro
; UNPACK_V4_32SSE_3A(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V4_32SSE_3A 4
	movdqa XMM_R0,  [VIF_SRC]
	movdqa XMM_R1,  [VIF_SRC+16]
	movdqa XMM_R2,  [VIF_SRC+32]
	
	UNPACK3_SSE %1,%2,%3,%4
	
	add VIF_SRC, 48
%endmacro 

; UNPACK_V4_32SSE_3(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V4_32SSE_3 4
	movdqu XMM_R0,  [VIF_SRC]
	movdqu XMM_R1,  [VIF_SRC+16]
	movdqu XMM_R2,  [VIF_SRC+32]
	
	UNPACK3_SSE %1,%2,%3,%4
	
	add VIF_SRC, 48
%endmacro

; UNPACK_V4_32SSE_2A(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V4_32SSE_2A 4
	movdqa XMM_R0,  [VIF_SRC]
	movdqa XMM_R1,  [VIF_SRC+16]
	
	UNPACK2_SSE %1,%2,%3,%4
	
	add VIF_SRC, 32
%endmacro

; UNPACK_V4_32SSE_2(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V4_32SSE_2 4
	movdqu XMM_R0,  [VIF_SRC]
	movdqu XMM_R1,  [VIF_SRC+16]
	
	UNPACK2_SSE %1,%2,%3,%4
	
	add VIF_SRC, 32
%endmacro

; UNPACK_V4_32SSE_1A(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V4_32SSE_1A 4
	movdqa XMM_R0,  [VIF_SRC]
	
	UNPACK1_SSE %1,%2,%3,%4
	
	add VIF_SRC, 16
%endmacro

; UNPACK_V4_32SSE_1(CL, TOTALCL, MaskType, ModeType) 
%macro UNPACK_V4_32SSE_1 4
	movdqu XMM_R0,  [VIF_SRC]
	
	UNPACK1_SSE %1,%2,%3,%4
	
	add VIF_SRC, 16
%endmacro

; V4-16
; UNPACK_V4_16SSE_4A(CL, TOTALCL, MaskType, ModeType) 
%macro UNPACK_V4_16SSE_4A 4
	punpcklwd XMM_R0,  [VIF_SRC]
	punpckhwd XMM_R1,  [VIF_SRC]
	punpcklwd XMM_R2,  [VIF_SRC+16]
	punpckhwd XMM_R3,  [VIF_SRC+16]
	
	UNPACK_RIGHTSHIFT XMM_R1, 16
	UNPACK_RIGHTSHIFT XMM_R3, 16
	UNPACK_RIGHTSHIFT XMM_R0, 16
	UNPACK_RIGHTSHIFT XMM_R2, 16
	
	UNPACK4_SSE %1,%2,%3,%4
	
	add VIF_SRC, 32
%endmacro

; UNPACK_V4_16SSE_4(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V4_16SSE_4 4
	movdqu XMM_R0,  [VIF_SRC]
	movdqu XMM_R2,  [VIF_SRC+16]
	
	punpckhwd XMM_R1, XMM_R0
	punpckhwd XMM_R3, XMM_R2
	punpcklwd XMM_R0, XMM_R0
	punpcklwd XMM_R2, XMM_R2
	
	UNPACK_RIGHTSHIFT XMM_R1, 16
	UNPACK_RIGHTSHIFT XMM_R3, 16
	UNPACK_RIGHTSHIFT XMM_R0, 16
	UNPACK_RIGHTSHIFT XMM_R2, 16
	
	UNPACK4_SSE %1,%2,%3,%4
	
	add VIF_SRC, 32
%endmacro

; UNPACK_V4_16SSE_3A(CL, TOTALCL, MaskType, ModeType) 
%macro UNPACK_V4_16SSE_3A 4
	punpcklwd XMM_R0,  [VIF_SRC]
	punpckhwd XMM_R1,  [VIF_SRC]
	punpcklwd XMM_R2,  [VIF_SRC+16]
	
	UNPACK_RIGHTSHIFT XMM_R0, 16
	UNPACK_RIGHTSHIFT XMM_R1, 16
	UNPACK_RIGHTSHIFT XMM_R2, 16
	
	UNPACK3_SSE %1,%2,%3,%4
	
	add VIF_SRC, 24
%endmacro

;	UNPACK_V4_16SSE_3(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V4_16SSE_3 4
	movdqu XMM_R0,  [VIF_SRC]
	movq XMM_R2,  [VIF_SRC+16]
	
	punpckhwd XMM_R1, XMM_R0
	punpcklwd XMM_R0, XMM_R0
	punpcklwd XMM_R2, XMM_R2
	
	UNPACK_RIGHTSHIFT XMM_R0, 16
	UNPACK_RIGHTSHIFT XMM_R1, 16
	UNPACK_RIGHTSHIFT XMM_R2, 16
	
	UNPACK3_SSE %1,%2,%3,%4
	
	add VIF_SRC, 24
%endmacro

; UNPACK_V4_16SSE_2A(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V4_16SSE_2A 4
	punpcklwd XMM_R0,  [VIF_SRC]
	punpckhwd XMM_R1,  [VIF_SRC]
	
	UNPACK_RIGHTSHIFT XMM_R0, 16
	UNPACK_RIGHTSHIFT XMM_R1, 16
	
	UNPACK2_SSE %1,%2,%3,%4
	
	add VIF_SRC, 16
%endmacro

; UNPACK_V4_16SSE_2(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V4_16SSE_2 4
	movq XMM_R0,  [VIF_SRC]
	movq XMM_R1,  [VIF_SRC+8]
	
	punpcklwd XMM_R0, XMM_R0
	punpcklwd XMM_R1, XMM_R1
	
	UNPACK_RIGHTSHIFT XMM_R0, 16
	UNPACK_RIGHTSHIFT XMM_R1, 16
	
	UNPACK2_SSE %1,%2,%3,%4
	
	add VIF_SRC, 16
%endmacro

; UNPACK_V4_16SSE_1A(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V4_16SSE_1A 4
	punpcklwd XMM_R0,  [VIF_SRC]
	UNPACK_RIGHTSHIFT XMM_R0, 16
	
	UNPACK1_SSE %1,%2,%3,%4
	
	add VIF_SRC, 8
%endmacro

; UNPACK_V4_16SSE_1(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V4_16SSE_1 4
	movq XMM_R0,  [VIF_SRC]
	punpcklwd XMM_R0, XMM_R0
	UNPACK_RIGHTSHIFT XMM_R0, 16
	
	UNPACK1_SSE %1,%2,%3,%4

	add VIF_SRC, 8
%endmacro	
; V4-8
; UNPACK_V4_8SSE_4A(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V4_8SSE_4A 4
	punpcklbw XMM_R0,  [VIF_SRC]
	punpckhbw XMM_R2,  [VIF_SRC]
	
	punpckhwd XMM_R1, XMM_R0
	punpckhwd XMM_R3, XMM_R2
	punpcklwd XMM_R0, XMM_R0
	punpcklwd XMM_R2, XMM_R2
	
	UNPACK_RIGHTSHIFT XMM_R1, 24
	UNPACK_RIGHTSHIFT XMM_R3, 24
	UNPACK_RIGHTSHIFT XMM_R0, 24
	UNPACK_RIGHTSHIFT XMM_R2, 24

	UNPACK4_SSE %1,%2,%3,%4
	
	add VIF_SRC, 16
%endmacro

; UNPACK_V4_8SSE_4(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V4_8SSE_4 4
	movdqu XMM_R0,  [VIF_SRC]
	
	punpckhbw XMM_R2, XMM_R0
	punpcklbw XMM_R0, XMM_R0
	
	punpckhwd XMM_R3, XMM_R2
	punpckhwd XMM_R1, XMM_R0
	punpcklwd XMM_R2, XMM_R2
	punpcklwd XMM_R0, XMM_R0
	
	UNPACK_RIGHTSHIFT XMM_R3, 24
	UNPACK_RIGHTSHIFT XMM_R2, 24
	
	UNPACK_RIGHTSHIFT XMM_R0, 24
	UNPACK_RIGHTSHIFT XMM_R1, 24
	
	UNPACK4_SSE %1,%2,%3,%4
	
	add VIF_SRC, 16
%endmacro

; UNPACK_V4_8SSE_3A(CL, TOTALCL, MaskType, ModeType) 
%macro UNPACK_V4_8SSE_3A 4
	punpcklbw XMM_R0,  [VIF_SRC]
	punpckhbw XMM_R2,  [VIF_SRC]
	
	punpckhwd XMM_R1, XMM_R0
	punpcklwd XMM_R0, XMM_R0
	punpcklwd XMM_R2, XMM_R2
	
	UNPACK_RIGHTSHIFT XMM_R1, 24
	UNPACK_RIGHTSHIFT XMM_R0, 24
	UNPACK_RIGHTSHIFT XMM_R2, 24
	
	UNPACK3_SSE %1,%2,%3,%4
	
	add VIF_SRC, 12
%endmacro

; UNPACK_V4_8SSE_3(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V4_8SSE_3 4
	movq XMM_R0,  [VIF_SRC]
	movd XMM_R2, dword [VIF_SRC+8]
	
	punpcklbw XMM_R0, XMM_R0
	punpcklbw XMM_R2, XMM_R2
	
	punpckhwd XMM_R1, XMM_R0
	punpcklwd XMM_R2, XMM_R2
	punpcklwd XMM_R0, XMM_R0
	
	UNPACK_RIGHTSHIFT XMM_R1, 24
	UNPACK_RIGHTSHIFT XMM_R0, 24
	UNPACK_RIGHTSHIFT XMM_R2, 24
	
	UNPACK3_SSE %1,%2,%3,%4
	
	add VIF_SRC, 12
%endmacro

; UNPACK_V4_8SSE_2A(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V4_8SSE_2A 4
	punpcklbw XMM_R0,  [VIF_SRC]
	
	punpckhwd XMM_R1, XMM_R0
	punpcklwd XMM_R0, XMM_R0
	
	UNPACK_RIGHTSHIFT XMM_R1, 24
	UNPACK_RIGHTSHIFT XMM_R0, 24
	
	UNPACK2_SSE %1,%2,%3,%4
	
	add VIF_SRC, 8
%endmacro

; UNPACK_V4_8SSE_2(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V4_8SSE_2 4
	movq XMM_R0,  [VIF_SRC]
	
	punpcklbw XMM_R0, XMM_R0
	
	punpckhwd XMM_R1, XMM_R0
	punpcklwd XMM_R0, XMM_R0
	
	UNPACK_RIGHTSHIFT XMM_R1, 24
	UNPACK_RIGHTSHIFT XMM_R0, 24
	
	UNPACK2_SSE %1,%2,%3,%4
	
	add VIF_SRC, 8
%endmacro

; UNPACK_V4_8SSE_1A(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V4_8SSE_1A 4
	punpcklbw XMM_R0,  [VIF_SRC]
	punpcklwd XMM_R0, XMM_R0
	UNPACK_RIGHTSHIFT XMM_R0, 24
	
	UNPACK1_SSE %1,%2,%3,%4
	
	add VIF_SRC, 4
%endmacro

; UNPACK_V4_8SSE_1(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V4_8SSE_1 4
	movd XMM_R0, dword [VIF_SRC]
	punpcklbw XMM_R0, XMM_R0
	punpcklwd XMM_R0, XMM_R0
	UNPACK_RIGHTSHIFT XMM_R0, 24
	
	UNPACK1_SSE %1,%2,%3,%4
	
	add VIF_SRC, 4
%endmacro

; V4-5
extern s_TempDecompress

; DECOMPRESS_RGBA(OFFSET)
%macro DECOMPRESS_RGBA 1
	mov bl, al
	shl bl, 3
	mov byte [s_TempDecompress+%1], bl
	
	mov bx, ax
	shr bx, 2
	and bx, 0xf8
	mov byte [s_TempDecompress+%1+1], bl
	
	mov bx, ax
	shr bx, 7
	and bx, 0xf8
	mov byte [s_TempDecompress+%1+2], bl
	mov bx, ax
	shr bx, 8
	and bx, 0x80
	mov byte [s_TempDecompress+%1+3], bl
%endmacro

; UNPACK_V4_5SSE_4(CL, TOTALCL, MaskType, ModeType) 
%macro UNPACK_V4_5SSE_4 4
	mov eax, dword [VIF_SRC]
	DECOMPRESS_RGBA 0
	
	shr eax, 16
	DECOMPRESS_RGBA 4
	
	mov eax, dword [VIF_SRC+4]
	DECOMPRESS_RGBA 8
	
	shr eax, 16
	DECOMPRESS_RGBA 12
	
	movdqa XMM_R0,  [s_TempDecompress]
	
	punpckhbw XMM_R2, XMM_R0
	punpcklbw XMM_R0, XMM_R0
	
	punpckhwd XMM_R3, XMM_R2
	punpckhwd XMM_R1, XMM_R0
	punpcklwd XMM_R0, XMM_R0
	punpcklwd XMM_R2, XMM_R2
	
	psrld XMM_R0, 24
	psrld XMM_R1, 24
	psrld XMM_R2, 24
	psrld XMM_R3, 24
	
	UNPACK4_SSE %1,%2,%3,%4
	
	add VIF_SRC, 8
%endmacro

%define UNPACK_V4_5SSE_4A UNPACK_V4_5SSE_4

; UNPACK_V4_5SSE_3(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V4_5SSE_3 4
	mov eax, dword [VIF_SRC]
	DECOMPRESS_RGBA 0
	
	shr eax, 16
	DECOMPRESS_RGBA 4
	
  mov eax, dword [VIF_SRC]
	DECOMPRESS_RGBA 8
	
	movdqa XMM_R0,  [s_TempDecompress]
	
	punpckhbw XMM_R2, XMM_R0
	punpcklbw XMM_R0, XMM_R0
	
	punpckhwd XMM_R1, XMM_R0
	punpcklwd XMM_R0, XMM_R0
	punpcklwd XMM_R2, XMM_R2
	
	psrld XMM_R0, 24
	psrld XMM_R1, 24
	psrld XMM_R2, 24
	
	UNPACK3_SSE %1,%2,%3,%4
	
	add VIF_SRC, 6
%endmacro
%define UNPACK_V4_5SSE_3A UNPACK_V4_5SSE_3

;  UNPACK_V4_5SSE_2(CL, TOTALCL, MaskType, ModeType) 
%macro UNPACK_V4_5SSE_2 4
	mov eax, dword  [VIF_SRC]
	DECOMPRESS_RGBA 0
	
	shr eax, 16
	DECOMPRESS_RGBA 4
	
	movq XMM_R0,  [s_TempDecompress]
	
	punpcklbw XMM_R0, XMM_R0
	
	punpckhwd XMM_R1, XMM_R0
	punpcklwd XMM_R0, XMM_R0
	
	psrld XMM_R0, 24
	psrld XMM_R1, 24
	
	UNPACK2_SSE %1,%2,%3,%4
	
	add VIF_SRC, 4
%endmacro

%define UNPACK_V4_5SSE_2A UNPACK_V4_5SSE_2

; UNPACK_V4_5SSE_1(CL, TOTALCL, MaskType, ModeType)
%macro UNPACK_V4_5SSE_1 4
	mov ax, word [VIF_SRC]
	DECOMPRESS_RGBA 0 
	
	movd XMM_R0, dword [s_TempDecompress]
	punpcklbw XMM_R0, XMM_R0
	punpcklwd XMM_R0, XMM_R0
	
	psrld XMM_R0, 24
	
	UNPACK1_SSE %1,%2,%3,%4
	
	add VIF_SRC, 2
%endmacro

%define UNPACK_V4_5SSE_1A UNPACK_V4_5SSE_1

;%pragma warning(disable:4731)

; SAVE_ROW_REG_BASE 
%macro SAVE_ROW_REG_BASE 0
	mov VIF_TMPADDR, [vifRow]
	movdqa  [VIF_TMPADDR], XMM_ROW
	mov VIF_TMPADDR, [vifRegs]
	movss [VIF_TMPADDR+0x100], XMM_ROW
	psrldq XMM_ROW, 4
	movss [VIF_TMPADDR+0x110], XMM_ROW
	psrldq XMM_ROW, 4
	movss [VIF_TMPADDR+0x120], XMM_ROW
	psrldq XMM_ROW, 4
	movss [VIF_TMPADDR+0x130], XMM_ROW
%endmacro

%define SAVE_NO_REG

%ifdef __x86_64__

%macro INIT_ARGS 0
	mov rax,  [vifRow]
	mov r9,  [_vifCol]
	movaps xmm6, XMMWORD [rax]
	movaps xmm7, XMMWORD [r9]
%endmacro

%macro POP_REGS 0
%endmacro 

%macro INC_STACK 0-1
	add rsp,8
%endmacro

%else

; 32 bit versions have the args on the stack
%macro INIT_ARGS 0
    push edi
    push esi
    push ebx
    mov VIF_DST, dword [esp+4+12]
    mov VIF_SRC, dword [esp+8+12]
    mov VIF_SIZE, dword [esp+12+12]
%endmacro

%macro POP_REGS 0
    pop ebx
    pop esi
    pop edi
%endmacro

%macro INC_STACK 0-1
	add esp, 4
%endmacro
        
%endif
        
; qsize - bytes of compressed size of 1 decompressed 
; int UNPACK_SkippingWrite_##name##_##sign##_##MaskType##_##ModeType(u32* dest, u32* data, int dmasize)

; defUNPACK_SkippingWrite(name, MaskType, ModeType, qsize, sign, SAVE_ROW_REG) 
%macro defUNPACK_SkippingWrite 6
%ifdef __APPLE__
global _UNPACK_SkippingWrite_%1_%5_%2_%3
_UNPACK_SkippingWrite_%1_%5_%2_%3:
%else
global UNPACK_SkippingWrite_%1_%5_%2_%3
UNPACK_SkippingWrite_%1_%5_%2_%3:
%endif
    INIT_ARGS
    mov VIF_TMPADDR, [vifRegs]
    movzx VIF_INC, byte [VIF_TMPADDR + 0x40]
    movzx VIF_SAVEEBX, byte [VIF_TMPADDR + 0x41]
    sub VIF_INC, VIF_SAVEEBX
    shl VIF_INC, 4
	
    cmp VIF_SAVEEBXd, 1
    je %1_%5_%2_%3_WL1
    cmp VIF_SAVEEBXd, 2
    je near %1_%5_%2_%3_WL2 
    cmp VIF_SAVEEBXd, 3
    je near %1_%5_%2_%3_WL3
    jmp %1_%5_%2_%3_WL4 
		
%1_%5_%2_%3_WL1: 
  UNPACK_Start_Setup_%2_SSE_%3 0
	cmp VIF_SIZE, %4
	jl near %1_%5_%2_%3_C1_Done3
	add VIF_INC, 16
	
; first align VIF_SRC to 16 bytes 
%1_%5_%2_%3_C1_Align16: 
	test VIF_SRC, 15
	jz near %1_%5_%2_%3_C1_UnpackAligned 
	
	UNPACK_%1SSE_1 0, 1, %2,%3 
	
	cmp VIF_SIZE, (2*%4)
	jl near %1_%5_%2_%3_C1_DoneWithDec
	sub VIF_SIZE, %4
	jmp near %1_%5_%2_%3_C1_Align16
	
%1_%5_%2_%3_C1_UnpackAligned: 
	cmp VIF_SIZE, (2*%4)
	jl near %1_%5_%2_%3_C1_Unpack1 
	cmp VIF_SIZE, (3*%4)
	jl near %1_%5_%2_%3_C1_Unpack2
	cmp VIF_SIZE, (4*%4)
	jl near %1_%5_%2_%3_C1_Unpack3

	prefetchnta [VIF_SRC + 64]
	
%1_%5_%2_%3_C1_Unpack4: 
UNPACK_%1SSE_4A 0, 1, %2,%3
	cmp VIF_SIZE, (8*%4)
	jl %1_%5_%2_%3_C1_DoneUnpack4 
	sub VIF_SIZE, (4*%4)
	jmp near %1_%5_%2_%3_C1_Unpack4 
	
%1_%5_%2_%3_C1_DoneUnpack4: 
	sub VIF_SIZE, (4*%4)
	cmp VIF_SIZE, %4
	jl near %1_%5_%2_%3_C1_Done3
	cmp VIF_SIZE, (%4)
	jl near %1_%5_%2_%3_C1_Unpack1 
	cmp VIF_SIZE, (%4)
	jl near %1_%5_%2_%3_C1_Unpack2 
; fall through
%1_%5_%2_%3_C1_Unpack3: 
	UNPACK_%1SSE_3A 0, 1, %2,%3
	
	sub VIF_SIZE, (3*%4)
	jmp near %1_%5_%2_%3_C1_Done3
	
%1_%5_%2_%3_C1_Unpack2:
	UNPACK_%1SSE_2A 0, 1, %2,%3
	
	sub VIF_SIZE, (2*%4)
	jmp near %1_%5_%2_%3_C1_Done3
	
%1_%5_%2_%3_C1_Unpack1: 
UNPACK_%1SSE_1A 0, 1, %2,%3
%1_%5_%2_%3_C1_DoneWithDec:
	sub VIF_SIZE, %4
%1_%5_%2_%3_C1_Done3:
	%6
	mov eax, VIF_SIZE
  POP_REGS
  ret
%1_%5_%2_%3_WL2: 
	cmp VIF_SIZE, (2*%4)
	jl near %1_%5_%2_%3_C2_Done3
%1_%5_%2_%3_C2_Unpack: 
	UNPACK_%1SSE_2 0, 0, %2,%3

	add VIF_DST, VIF_INC; take into account wl
	cmp VIF_SIZE, (4*%4)
	jl %1_%5_%2_%3_C2_Done2 
	sub VIF_SIZE, (2*%4)
	jmp near %1_%5_%2_%3_C2_Unpack ; unpack next
	
%1_%5_%2_%3_C2_Done2: 
	sub VIF_SIZE, (2*%4)
%1_%5_%2_%3_C2_Done3:
	cmp VIF_SIZE, %4
  ; execute left over qw 
	jl near %1_%5_%2_%3_C2_Done4
	UNPACK_%1SSE_1 0, 0,%2,%3
	sub VIF_SIZE, %4
%1_%5_%2_%3_C2_Done4:
	%6
  mov eax, VIF_SIZE
  POP_REGS
	ret
	
%1_%5_%2_%3_WL3:
	cmp VIF_SIZE, (3*%4)
	jl near %1_%5_%2_%3_C3_Done5
%1_%5_%2_%3_C3_Unpack: 
	UNPACK_%1SSE_3 0, 0, %2,%3
	
	add VIF_DST, VIF_INC; /* take into account wl */ \
	cmp VIF_SIZE, (6*%4)
	jl %1_%5_%2_%3_C3_Done2
	sub VIF_SIZE, (3*%4)
	jmp near %1_%5_%2_%3_C3_Unpack	; unpack next
%1_%5_%2_%3_C3_Done2:
	sub VIF_SIZE, (3*%4)
%1_%5_%2_%3_C3_Done5:
	cmp VIF_SIZE, %4
	jl near %1_%5_%2_%3_C3_Done4
; execute left over qw 
	cmp VIF_SIZE, (2*%4)
	jl near %1_%5_%2_%3_C3_Done3
; process 2 qws
	UNPACK_%1SSE_2 0, 0, %2,%3
	sub VIF_SIZE, (2*%4)
	jmp near %1_%5_%2_%3_C3_Done4
%1_%5_%2_%3_C3_Done3:
; process 1 qw 
	sub VIF_SIZE, %4
	UNPACK_%1SSE_1 0, 0, %2,%3
%1_%5_%2_%3_C3_Done4: 
	%6
  mov eax, VIF_SIZE
  POP_REGS
  ret
%1_%5_%2_%3_WL4: ; >= 4
	sub VIF_SAVEEBX, 3
	push VIF_INC
	cmp VIF_SIZE, %4
	jl near %1_%5_%2_%3_C4_Done
%1_%5_%2_%3_C4_Unpack:
	cmp VIF_SIZE, (3*%4)
	jge near %1_%5_%2_%3_C4_Unpack3
	cmp VIF_SIZE, (2*%4)
	jge near %1_%5_%2_%3_C4_Unpack2
	
	UNPACK_%1SSE_1 0, 0, %2,%3
; not enough data left
	sub VIF_SIZE, %4
	jmp near %1_%5_%2_%3_C4_Done
%1_%5_%2_%3_C4_Unpack2: 
	UNPACK_%1SSE_2 0, 0, %2,%3
; not enough data left
	sub VIF_SIZE, (2*%4)
	jmp near %1_%5_%2_%3_C4_Done
%1_%5_%2_%3_C4_Unpack3: 
	UNPACK_%1SSE_3 0, 0, %2,%3
	sub VIF_SIZE, (3*%4)
; more data left, process 1qw at a time 
	mov VIF_INC, VIF_SAVEEBX
%1_%5_%2_%3_C4_UnpackX:
; check if any data left
	cmp VIF_SIZE, %4
	jl near %1_%5_%2_%3_C4_Done
	UNPACK_%1SSE_1 3, 0, %2,%3

	sub VIF_SIZE, %4
	cmp VIF_INC, 1
	je %1_%5_%2_%3_C4_DoneLoop
	sub VIF_INC, 1
	jmp near %1_%5_%2_%3_C4_UnpackX
%1_%5_%2_%3_C4_DoneLoop:
	add VIF_DST, [VIF_ESP]	; take into account wl
	cmp VIF_SIZE, %4
	jl %1_%5_%2_%3_C4_Done
	jmp near %1_%5_%2_%3_C4_Unpack	; unpack next
%1_%5_%2_%3_C4_Done: 
	%6
	INC_STACK
  mov eax, VIF_SIZE
  POP_REGS
  ret
%endmacro        
%define UNPACK_RIGHTSHIFT psrld
; defUNPACK_SkippingWrite2(name, qsize)
%macro defUNPACK_SkippingWrite2 2
	defUNPACK_SkippingWrite %1, Regular, 0, %2, u, SAVE_NO_REG
	defUNPACK_SkippingWrite %1, Regular, 1, %2, u, SAVE_NO_REG
	defUNPACK_SkippingWrite %1, Regular, 2, %2, u, SAVE_ROW_REG_BASE
	defUNPACK_SkippingWrite %1, Mask, 0, %2, u, SAVE_NO_REG
	defUNPACK_SkippingWrite %1, Mask, 1, %2, u, SAVE_NO_REG
	defUNPACK_SkippingWrite %1, Mask, 2, %2, u, SAVE_ROW_REG_BASE
	defUNPACK_SkippingWrite %1, WriteMask, 0, %2, u, SAVE_NO_REG
	defUNPACK_SkippingWrite %1, WriteMask, 1, %2, u, SAVE_NO_REG
	defUNPACK_SkippingWrite %1, WriteMask, 2, %2, u, SAVE_ROW_REG_BASE
%endmacro


defUNPACK_SkippingWrite2 S_32, 4
defUNPACK_SkippingWrite2 S_16, 2
defUNPACK_SkippingWrite2 S_8, 1
defUNPACK_SkippingWrite2 V2_32, 8
defUNPACK_SkippingWrite2 V2_16, 4
defUNPACK_SkippingWrite2 V2_8, 2
defUNPACK_SkippingWrite2 V3_32, 12
defUNPACK_SkippingWrite2 V3_16, 6
defUNPACK_SkippingWrite2 V3_8, 3
defUNPACK_SkippingWrite2 V4_32, 16
defUNPACK_SkippingWrite2 V4_16, 8
defUNPACK_SkippingWrite2 V4_8, 4
defUNPACK_SkippingWrite2 V4_5, 2

%undef UNPACK_RIGHTSHIFT
;%undef defUNPACK_SkippingWrite2

%define UNPACK_RIGHTSHIFT psrad
; defUNPACK_SkippingWrite2a(name, qsize)
%macro defUNPACK_SkippingWrite2a 2
	defUNPACK_SkippingWrite %1, Mask, 0, %2, s, SAVE_NO_REG
	defUNPACK_SkippingWrite %1, Regular, 0, %2, s, SAVE_NO_REG
	defUNPACK_SkippingWrite %1, Regular, 1, %2, s, SAVE_NO_REG
	defUNPACK_SkippingWrite %1, Regular, 2, %2, s, SAVE_ROW_REG_BASE
	defUNPACK_SkippingWrite %1, Mask, 1, %2, s, SAVE_NO_REG
	defUNPACK_SkippingWrite %1, Mask, 2, %2, s, SAVE_ROW_REG_BASE
	defUNPACK_SkippingWrite %1, WriteMask, 0, %2, s, SAVE_NO_REG
	defUNPACK_SkippingWrite %1, WriteMask, 1, %2, s, SAVE_NO_REG
	defUNPACK_SkippingWrite %1, WriteMask, 2, %2, s, SAVE_ROW_REG_BASE
%endmacro
defUNPACK_SkippingWrite2a S_16, 2
defUNPACK_SkippingWrite2a S_8, 1
defUNPACK_SkippingWrite2a V2_16, 4
defUNPACK_SkippingWrite2a V2_8, 2
defUNPACK_SkippingWrite2a V3_16, 6
defUNPACK_SkippingWrite2a V3_8, 3
defUNPACK_SkippingWrite2a V4_16, 8
defUNPACK_SkippingWrite2a V4_8, 4

;%undef UNPACK_RIGHTSHIFT
;%undef defUNPACK_SkippingWrite2

