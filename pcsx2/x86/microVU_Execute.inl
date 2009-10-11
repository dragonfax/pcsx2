/*  Pcsx2 - Pc Ps2 Emulator
 *  Copyright (C) 2009  Pcsx2 Team
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *  
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA
 */

#pragma once

//------------------------------------------------------------------
// Dispatcher Functions
//------------------------------------------------------------------

// Generates the code for entering recompiled blocks
void mVUdispatcherA(mV) {
	mVU->startFunct = x86Ptr;

	// __fastcall = The first two DWORD or smaller arguments are passed in ECX and EDX registers; all other arguments are passed right to left.
	if (!isVU1)	{ CALLFunc((uptr)mVUexecuteVU0); }
	else		{ CALLFunc((uptr)mVUexecuteVU1); }

	// Backup cpu state
	PUSH32R(EBX);
	PUSH32R(EBP);
	PUSH32R(ESI);
	PUSH32R(EDI);

	// Load VU's MXCSR state
	SSE_LDMXCSR((uptr)&g_sseVUMXCSR);

	// Load Regs
#ifdef CHECK_MACROVU0
	MOV32MtoR(gprF0, (uptr)&mVU->regs->VI[REG_STATUS_FLAG].UL);
	MOV32RtoR(gprF1, gprF0);
	MOV32RtoR(gprF2, gprF0);
	MOV32RtoR(gprF3, gprF0);
#else
	mVUallocSFLAGd((uptr)&mVU->regs->VI[REG_STATUS_FLAG].UL, 1);
#endif
	
	SSE_MOVAPS_M128_to_XMM(xmmT1, (uptr)&mVU->regs->VI[REG_MAC_FLAG].UL);
	SSE_SHUFPS_XMM_to_XMM (xmmT1, xmmT1, 0);
	SSE_MOVAPS_XMM_to_M128((uptr)mVU->macFlag, xmmT1);

	SSE_MOVAPS_M128_to_XMM(xmmT1, (uptr)&mVU->regs->VI[REG_CLIP_FLAG].UL);
	SSE_SHUFPS_XMM_to_XMM (xmmT1, xmmT1, 0);
	SSE_MOVAPS_XMM_to_M128((uptr)mVU->clipFlag, xmmT1);

	SSE_MOVAPS_M128_to_XMM(xmmT1, (uptr)&mVU->regs->VI[REG_P].UL);
	SSE_MOVAPS_M128_to_XMM(xmmPQ, (uptr)&mVU->regs->VI[REG_Q].UL);
	SSE_SHUFPS_XMM_to_XMM(xmmPQ, xmmT1, 0); // wzyx = PPQQ

	// Jump to Recompiled Code Block
	JMPR(EAX);
}

// Generates the code to exit from recompiled blocks
void mVUdispatcherB(mV) {
	mVU->exitFunct = x86Ptr;

	// Load EE's MXCSR state
	SSE_LDMXCSR((uptr)&g_sseMXCSR);
	
	// __fastcall = The first two DWORD or smaller arguments are passed in ECX and EDX registers; all other arguments are passed right to left.
	if (!isVU1) { CALLFunc((uptr)mVUcleanUpVU0); }
	else		{ CALLFunc((uptr)mVUcleanUpVU1); }

	// Restore cpu state
	POP32R(EDI);
	POP32R(ESI);
	POP32R(EBP);
	POP32R(EBX);

	RET();

	mVUcacheCheck(x86Ptr, mVU->cache, 0x1000);
}

//------------------------------------------------------------------
// Execution Functions
//------------------------------------------------------------------

// Executes for number of cycles
microVUx(void*) __fastcall mVUexecute(u32 startPC, u32 cycles) {

	microVU* mVU = mVUx;
	//mVUprint("microVU%x: startPC = 0x%x, cycles = 0x%x", params vuIndex, startPC, cycles);
	
	mVUsearchProg<vuIndex>(); // Find and set correct program
	mVU->cycles		 = cycles;
	mVU->totalCycles = cycles;

	x86SetPtr(mVU->prog.x86ptr); // Set x86ptr to where last program left off
	return mVUblockFetch(mVU, startPC, (uptr)&mVU->prog.lpState);
}

//------------------------------------------------------------------
// Cleanup Functions
//------------------------------------------------------------------

microVUx(void) mVUcleanUp() {
	microVU* mVU = mVUx;
	//mVUprint("microVU: Program exited successfully!");
	//mVUprint("microVU: VF0 = {%x,%x,%x,%x}", params mVU->regs->VF[0].UL[0], mVU->regs->VF[0].UL[1], mVU->regs->VF[0].UL[2], mVU->regs->VF[0].UL[3]);
	//mVUprint("microVU: VI0 = %x", params mVU->regs->VI[0].UL);
	mVU->prog.x86ptr = x86Ptr;
	mVUcacheCheck(x86Ptr, mVU->prog.x86start, (uptr)(mVU->prog.x86end - mVU->prog.x86start));
	mVU->cycles = mVU->totalCycles - mVU->cycles;
	mVU->regs->cycle += mVU->cycles;
	cpuRegs.cycle += ((mVU->cycles < 3000) ? mVU->cycles : 3000) * Config.Hacks.VUCycleSteal;
	//static int ax = 0; ax++;
	//if (!(ax % 100000)) {
	//	for (u32 i = 0; i < (mVU->progSize / 2); i++) {
	//		if (mVUcurProg.block[i]) {
	//			mVUcurProg.block[i]->printInfo(i*8);
	//		}
	//	}
	//}
}

//------------------------------------------------------------------
// Caller Functions
//------------------------------------------------------------------

void* __fastcall mVUexecuteVU0(u32 startPC, u32 cycles) { 
	ALIGN_STACK();
	void* ptr =  mVUexecute<0>(startPC, cycles); 
	RESTORE_STACK();
	return ptr;
}
void* __fastcall mVUexecuteVU1(u32 startPC, u32 cycles) {
	ALIGN_STACK();
	void* ptr =  mVUexecute<1>(startPC, cycles); 
	RESTORE_STACK();
	return ptr;
}
void  __fastcall mVUcleanUpVU0() { 
	ALIGN_STACK();
	mVUcleanUp<0>();
	RESTORE_STACK();
}
void  __fastcall mVUcleanUpVU1() {
	ALIGN_STACK();
	mVUcleanUp<1>();
	RESTORE_STACK();
}

