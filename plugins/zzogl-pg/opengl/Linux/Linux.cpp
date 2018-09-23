/*  ZeroGS
 *  Copyright (C) 2002-2004  GSsoft Team
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

#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>

#include "GS.h"
#include "Linux.h"
#include "GLWin.h"

#include <map>

extern u32 THR_KeyEvent; // value for passing out key events beetwen threads
extern bool THR_bShift;
extern bool THR_bCtrl;

static map<string, confOptsStruct> mapConfOpts;
static gameHacks tempHacks;

EXPORT_C_(void) GSkeyEvent(keyEvent *ev)
{

}

void DisplayAdvancedDialog()
{
}

void DisplayDialog()
{
}

EXPORT_C_(void) GSconfigure()
{
	char strcurdir[256];
	if (getcwd(strcurdir, 256) == NULL) {
		fprintf(stderr, "Failed to get current working directory\n");
		return;
	}

	if (!(conf.loaded())) LoadConfig();

}

void SysMessage(const char *fmt, ...)
{
	va_list list;
	char msg[512];

	va_start(list, fmt);
	vsprintf(msg, fmt, list);
	va_end(list);

	if (msg[strlen(msg)-1] == '\n') msg[strlen(msg)-1] = 0;

	// TODO Console.WriteLn(msg);
}

EXPORT_C_(void) GSabout()
{
	SysMessage("ZZOgl PG: by Zeydlitz (PG version worked on by arcum42, gregory, and the pcsx2 development team). Based off of ZeroGS, by zerofrog.");
}

EXPORT_C_(s32) GStest()
{
	return 0;
}

void *SysLoadLibrary(char *lib)
{
	return dlopen(lib, RTLD_NOW | RTLD_GLOBAL);
}

void *SysLoadSym(void *lib, char *sym)
{
	void *ret = dlsym(lib, sym);

	if (ret == NULL) ZZLog::Debug_Log("null: %s", sym);

	return dlsym(lib, sym);
}

char *SysLibError()
{
	return dlerror();
}

void SysCloseLibrary(void *lib)
{
	dlclose(lib);
}
