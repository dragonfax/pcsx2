/*  Pcsx2 - Pc Ps2 Emulator
 *  Copyright (C) 2002-2009  Pcsx2 Team
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
 
#include "Linux.h"
#include "LnxSysExec.h"
#include "HostGui.h"


static bool sinit = false;
GtkWidget *FileSel;
static uptr current_offset = 0;
static uptr offset_counter = 0;
bool Slots[5] = { false, false, false, false, false };

#ifdef __APPLE__

#include <mach/mach.h>
#include <mach/mach_error.h>
#include <mach/thread_status.h>
#include <mach/exception.h>
#include <mach/task.h>
#include <pthread.h>

/* These are not defined in any header, although they are documented */
extern "C" boolean_t exc_server(mach_msg_header_t *,mach_msg_header_t *);
extern "C" kern_return_t exception_raise(
    mach_port_t,mach_port_t,mach_port_t,
    exception_type_t,exception_data_t,mach_msg_type_number_t);
extern "C" kern_return_t exception_raise_state(
    mach_port_t,mach_port_t,mach_port_t,
    exception_type_t,exception_data_t,mach_msg_type_number_t,
    thread_state_flavor_t*,thread_state_t,mach_msg_type_number_t,
    thread_state_t,mach_msg_type_number_t*);
extern "C" kern_return_t exception_raise_state_identity(
    mach_port_t,mach_port_t,mach_port_t,
    exception_type_t,exception_data_t,mach_msg_type_number_t,
    thread_state_flavor_t*,thread_state_t,mach_msg_type_number_t,
    thread_state_t,mach_msg_type_number_t*);

#define MAX_EXCEPTION_PORTS 16

static struct {
    mach_msg_type_number_t count;
    exception_mask_t      masks[MAX_EXCEPTION_PORTS];
    exception_handler_t   ports[MAX_EXCEPTION_PORTS];
    exception_behavior_t  behaviors[MAX_EXCEPTION_PORTS];
    thread_state_flavor_t flavors[MAX_EXCEPTION_PORTS];
} old_exc_ports;

static mach_port_t exception_port;

void *exception_handler(void *arg)
{
	mach_msg_server(exc_server, 2048, exception_port, 0);
}

/* The source code for Apple's GDB was used as a reference for the exception
   forwarding code. This code is similar to be GDB code only because there is 
   only one way to do it. */
static kern_return_t forward_exception(
        mach_port_t thread,
        mach_port_t task,
        exception_type_t exception,
        exception_data_t data,
        mach_msg_type_number_t data_count
) {
    int i;
    kern_return_t r;
    mach_port_t port;
    exception_behavior_t behavior;
    thread_state_flavor_t flavor;
    
    thread_state_data_t thread_state;
    mach_msg_type_number_t thread_state_count = THREAD_STATE_MAX;
        
    for(i=0;i<old_exc_ports.count;i++)
        if(old_exc_ports.masks[i] & (1 << exception))
            break;
    //if(i==old_exc_ports.count) ABORT("No handler for exception!");
    
    port = old_exc_ports.ports[i];
    behavior = old_exc_ports.behaviors[i];
    flavor = old_exc_ports.flavors[i];

    if(behavior != EXCEPTION_DEFAULT) {
        r = thread_get_state(thread,flavor,thread_state,&thread_state_count);
        if(r != KERN_SUCCESS)
    			return r;
		}
    
    switch(behavior) {
        case EXCEPTION_DEFAULT:
            r = exception_raise(port,thread,task,exception,data,data_count);
            break;
        case EXCEPTION_STATE:
            r = exception_raise_state(port,thread,task,exception,data,
                data_count,&flavor,thread_state,thread_state_count,
                thread_state,&thread_state_count);
            break;
        case EXCEPTION_STATE_IDENTITY:
            r = exception_raise_state_identity(port,thread,task,exception,data,
                data_count,&flavor,thread_state,thread_state_count,
                thread_state,&thread_state_count);
            break;
        default:
            r = KERN_FAILURE; /* make gcc happy */
            break;
    }
    
    if(behavior != EXCEPTION_DEFAULT) {
        r = thread_set_state(thread,flavor,thread_state,thread_state_count);
        if(r != KERN_SUCCESS)
					return r;
    }
    
    return r;
}

#define FWD() forward_exception(thread,task,exception,code,code_count)

extern "C" __attribute__ ((visibility("default"))) 
kern_return_t
catch_exception_raise(
   mach_port_t exception_port,mach_port_t thread,mach_port_t task,
   exception_type_t exception,exception_data_t code,
   mach_msg_type_number_t code_count
) {
	
	kern_return_t r;

	thread_state_flavor_t flavor = i386_EXCEPTION_STATE;
	mach_msg_type_number_t exc_state_count = x86_EXCEPTION_STATE_COUNT;
	i386_exception_state_t exc_state;

	// forward all the exceptions which aren't EXC_BAD_ACCESS further just in case
	if(exception != EXC_BAD_ACCESS) {
			return FWD();
	}

	r = thread_get_state(thread,flavor,
			(natural_t*)&exc_state,&exc_state_count);
   
	void* addr = (void *) exc_state.__faultvaddr;

	Source_PageFault->Dispatch( PageFaultInfo( (uptr)(addr) & ~m_pagemask ) );   	
   
	// resumes execution right where we left off (re-executes instruction that
	// caused the SIGSEGV).
	if( Source_PageFault->WasHandled() ) return KERN_SUCCESS;

	// Bad mojo!  Completely invalid address.
	// Instigate a trap if we're in a debugger, and if not then do a SIGKILL.

	wxTrap();

	return KERN_INVALID_ARGUMENT;
}
#undef FWD

/* These should never be called, but just in case...  */
extern "C"  __attribute__ ((visibility("default"))) 
kern_return_t catch_exception_raise_state(mach_port_name_t exception_port,
    int exception, exception_data_t code, mach_msg_type_number_t codeCnt,
    int flavor, thread_state_t old_state, int old_stateCnt,
    thread_state_t new_state, int new_stateCnt)
{
    return(KERN_INVALID_ARGUMENT);
}
extern "C"  __attribute__ ((visibility("default"))) 
kern_return_t catch_exception_raise_state_identity(
    mach_port_name_t exception_port, mach_port_t thread, mach_port_t task,
    int exception, exception_data_t code, mach_msg_type_number_t codeCnt,
    int flavor, thread_state_t old_state, int old_stateCnt, 
    thread_state_t new_state, int new_stateCnt)
{
    return(KERN_INVALID_ARGUMENT);
}

#endif

__noinline void InstallLinuxExceptionHandler()
{
#ifndef __APPLE__
	struct sigaction sa;
	
	sigemptyset(&sa.sa_mask);
	sa.sa_flags = SA_SIGINFO;
	sa.sa_sigaction = &SysPageFaultExceptionFilter;
	//int res = sigaction(SIGSEGV, &sa, NULL); 
	int res = sigaction(SIGBUS,&sa, NULL);	
#else
	kern_return_t r;
	mach_port_t me;
	pthread_t thread;
	pthread_attr_t attr;
	exception_mask_t mask;

	me = mach_task_self();
	r = mach_port_allocate(me,MACH_PORT_RIGHT_RECEIVE,&exception_port);
	if(r != MACH_MSG_SUCCESS) Console.WriteLn("mach_port_allocate failed...");
	
	r = mach_port_insert_right(me,exception_port,exception_port,
		MACH_MSG_TYPE_MAKE_SEND);
	if(r != MACH_MSG_SUCCESS) Console.WriteLn("mach_port_insert_right failed...");

  mask = EXC_MASK_BAD_ACCESS;	// this is equivalent to SIGSEGV in linux world

	/* get the old exception ports */
	r = task_get_exception_ports(
			me,
			mask,
			old_exc_ports.masks,
			&old_exc_ports.count,
			old_exc_ports.ports,
			old_exc_ports.behaviors,
			old_exc_ports.flavors
	);
	if(r != MACH_MSG_SUCCESS) Console.WriteLn("task_get_exception_ports failed...");

	/* set the new exception ports */
	r = task_set_exception_ports(
			me,
			mask,
			exception_port,
			EXCEPTION_DEFAULT,
			MACHINE_THREAD_STATE
	);
	if(r != MACH_MSG_SUCCESS) Console.WriteLn("task_set_exception_ports failed...");	

	// create the exception handling thread
	if(pthread_attr_init(&attr) != 0) Console.WriteLn("pthread_attr_init failed...");
	if(pthread_attr_setdetachstate(&attr,PTHREAD_CREATE_DETACHED) != 0) 
			Console.WriteLn("pthread_attr_setdetachedstate failed...");
	
	if(pthread_create(&thread,&attr,exception_handler,NULL) != 0)
			Console.WriteLn("pthread_create for mach exception handler failed...");
	pthread_attr_destroy(&attr);	
#endif
}

__noinline void ReleaseLinuxExceptionHandler()
{
	// This may be called too early or something, since implementing it causes all games to segfault.
	// I'll look in to it. --arcum42
} 
 
__noinline void KillLinuxExceptionHandler()
{
	struct sigaction sa;
	
	sigemptyset(&sa.sa_mask);
	sa.sa_flags = SA_RESETHAND;
	//sa.sa_sigaction = &SysPageFaultExceptionFilter;
	//int res = sigaction(SIGSEGV, &sa, NULL);
	int res = sigaction(SIGBUS,&sa, NULL);
}
static const uptr m_pagemask = getpagesize()-1;

// Linux implementation of SIGSEGV handler.  Bind it using sigaction().
__noinline void SysPageFaultExceptionFilter( int signal, siginfo_t *info, void * )
{
	// get bad virtual address
	uptr offset = (u8*)info->si_addr - psM;
	
	if (offset != current_offset)
	{
		current_offset = offset;
		offset_counter = 0;
	}
	else
	{
		offset_counter++;
		if (offset_counter > 500) 
		{
			DevCon::Status( "Offset 0x%x endlessly repeating. Aborting.", params offset );
			KillLinuxExceptionHandler();
			assert( false );
		}
	}

	if (offset>=Ps2MemSize::Base)
	{
		// Bad mojo!  Completely invalid address.
		// Instigate a crash or abort emulation or something.
		DevCon::Status( "Offset 0x%x invalid. Legit SIGSEGV. Aborting.", params offset );
		KillLinuxExceptionHandler();
		assert( false );
	}
	
	mmap_ClearCpuBlock( offset & ~m_pagemask );
}

#define CmdSwitchIs( text ) ( stricmp( token, text ) == 0 )

bool ParseCommandLine(int argc, const char *argv[])
{
	int i = 1;
	
	g_Startup.Enabled		= false;
	g_Startup.NoGui			= false;
	g_Startup.ImageName		= NULL;
	g_Startup.ElfFile		= NULL;

	g_Startup.StartupMode	= Startup_FromCDVD;
	g_Startup.SkipBios		= true;
	g_Startup.CdvdSource	= CDVDsrc_Plugin;

	bool _legacy_ForceElfLoad = false;

	while (i < argc)
	{
		const char* token = argv[i++];

		if (CmdSwitchIs("-help") || CmdSwitchIs("--help") || CmdSwitchIs("-h"))
		{
			//Msgbox::Alert( phelpmsg );
			return false;
		}
		else if (CmdSwitchIs("-nogui"))
		{
			g_Startup.NoGui = true;
			g_Startup.Enabled = true;
		}
		else if( CmdSwitchIs( "skipbios" ) ) {
			g_Startup.SkipBios = true;
		}
		else if( CmdSwitchIs( "nodisc" ) ) {
			g_Startup.CdvdSource = CDVDsrc_NoDisc;
			g_Startup.Enabled = true;
		}
		else if( CmdSwitchIs( "usecd" ) ) {
			g_Startup.CdvdSource = CDVDsrc_Plugin;
			g_Startup.Enabled = true;
		}
		else if( CmdSwitchIs( "elf" ) ) {
			g_Startup.StartupMode = Startup_FromELF;
			token = argv[i++];
			g_Startup.ElfFile = token;
			g_Startup.Enabled = true;
		}

		// depreciated command switch
		else if (CmdSwitchIs("-bootmode")) 
		{
			token = argv[i++];
			int mode = atoi( token );
			g_Startup.Enabled = true;
			g_Startup.SkipBios = !( mode & 0x10000 );
			switch( mode & 0xf )
			{
				case 0:
					g_Startup.CdvdSource = CDVDsrc_Plugin;
				break;

				case 1:
					_legacy_ForceElfLoad = true;
				break;

				case 2:
					g_Startup.CdvdSource = CDVDsrc_Iso;
				break;

				case 3:
					g_Startup.CdvdSource = CDVDsrc_NoDisc;
				break;
			}
		}

		else if (CmdSwitchIs("-loadgs"))
		{
			g_pRunGSState = argv[i++];
		}			
		else if (CmdSwitchIs("-gs"))
		{
			token = argv[i++];
			g_Startup.gsdll = token;
		}
		else if (CmdSwitchIs("-cdvd"))
		{
			token = argv[i++];
			g_Startup.cdvddll = token;
		}
		else if (CmdSwitchIs("-spu"))
		{
			token = argv[i++];
			g_Startup.spudll = token;
		}
		else if (CmdSwitchIs("-pad"))
		{
			token = argv[i++];
			g_Startup.pad1dll = token;
			g_Startup.pad2dll = token;
		}
		else if (CmdSwitchIs("-pad1"))
		{
			token = argv[i++];
			g_Startup.pad1dll = token;
		}
		else if (CmdSwitchIs("-pad2"))
		{
			token = argv[i++];
			g_Startup.pad2dll = token;
		}
		else if (CmdSwitchIs("-loadgs"))
		{
			token = argv[i++];
			g_pRunGSState = token;
		}
		else
		{
			printf("opening file %s\n", token);

			g_Startup.ImageName = token;
			g_Startup.Enabled = true;
			g_Startup.CdvdSource = CDVDsrc_Iso;

			if ( _legacy_ForceElfLoad )
			{
				// This retains compatibility with the older Bootmode switch.
				
				// Not totally sure what this should be set to, 
				// but I'll take compiling over everything working properly for the moment.
				//g_Startup.ElfFile = file;
				g_Startup.StartupMode = Startup_FromELF;
				g_Startup.CdvdSource = CDVDsrc_Plugin;
			}
		}
	}
	return true;
}
void SysPrintf(const char *fmt, ...)
{
	va_list list;
	char msg[512];

	va_start(list, fmt);
	vsnprintf(msg, 511, fmt, list);
	msg[511] = '\0';
	va_end(list);

	Console::Write(msg);
}

static std::string str_Default( "default" );

void RunGui()
{
	PCSX2_MEM_PROTECT_BEGIN();

	LoadPatch( str_Default );
	if( g_Startup.NoGui )
	{
		// Initially bypass GUI and start PCSX2 directly.
		CDVDsys_ChangeSource( g_Startup.CdvdSource );
		if( !OpenCDVD( g_Startup.ImageName ) ) return;
		
		if (OpenPlugins() == -1) return;
		
		SysPrepareExecution( (g_Startup.StartupMode == Startup_FromELF) ? g_Startup.ImageName : NULL, !g_Startup.SkipBios );
	}
	
	// Just exit immediately if the user disabled the GUI
	if( g_Startup.NoGui ) return;
	
	StartGui();
	
	PCSX2_MEM_PROTECT_END();
}

void OnStates_Load(GtkMenuItem *menuitem, gpointer user_data)
{
	char *name;
	int i;
	
	if (GTK_BIN (menuitem)->child)
	{
		GtkWidget *child = GTK_BIN (menuitem)->child;
  
		if (GTK_IS_LABEL (child)) 
			gtk_label_get (GTK_LABEL (child), &name);
		else
			return;
	}
	
	sscanf(name, "Slot %d", &i);
	States_Load(i);
	RefreshMenuSlots();
}

void OnLoadOther_Ok(GtkButton* button, gpointer user_data)
{
	gchar *File;
	char str[g_MaxPath];

	File = (gchar*)gtk_file_selection_get_filename(GTK_FILE_SELECTION(FileSel));
	strcpy(str, File);
	gtk_widget_destroy(FileSel);
	States_Load(str);
	RefreshMenuSlots();
}

void OnLoadOther_Cancel(GtkButton* button, gpointer user_data)
{
	gtk_widget_destroy(FileSel);
}

void OnStates_LoadOther(GtkMenuItem *menuitem, gpointer user_data)
{
	GtkWidget *Ok, *Cancel;

	FileSel = gtk_file_selection_new(_("Select State File"));
	gtk_file_selection_set_filename(GTK_FILE_SELECTION(FileSel), SSTATES_DIR "/");

	Ok = GTK_FILE_SELECTION(FileSel)->ok_button;
	gtk_signal_connect(GTK_OBJECT(Ok), "clicked", GTK_SIGNAL_FUNC(OnLoadOther_Ok), NULL);
	gtk_widget_show(Ok);

	Cancel = GTK_FILE_SELECTION(FileSel)->cancel_button;
	gtk_signal_connect(GTK_OBJECT(Cancel), "clicked", GTK_SIGNAL_FUNC(OnLoadOther_Cancel), NULL);
	gtk_widget_show(Cancel);

	gtk_widget_show(FileSel);
	gdk_window_raise(FileSel->window);
}

void OnStates_Save(GtkMenuItem *menuitem, gpointer user_data)
{
	char *name;
	int i;
	
	if (GTK_BIN (menuitem)->child)
	{
		GtkWidget *child = GTK_BIN (menuitem)->child;
  
		if (GTK_IS_LABEL (child)) 
			gtk_label_get (GTK_LABEL (child), &name);
		else
			return;
	}
	
	sscanf(name, "Slot %d", &i);
	States_Save(i);
}

void OnSaveOther_Ok(GtkButton* button, gpointer user_data)
{
	gchar *File;
	char str[g_MaxPath];

	File = (gchar*)gtk_file_selection_get_filename(GTK_FILE_SELECTION(FileSel));
	strcpy(str, File);
	gtk_widget_destroy(FileSel);

	States_Save(str);
}

void OnSaveOther_Cancel(GtkButton* button, gpointer user_data)
{
	gtk_widget_destroy(FileSel);
}

void OnStates_SaveOther(GtkMenuItem *menuitem, gpointer user_data)
{
	GtkWidget *Ok, *Cancel;

	FileSel = gtk_file_selection_new(_("Select State File"));
	gtk_file_selection_set_filename(GTK_FILE_SELECTION(FileSel), SSTATES_DIR "/");

	Ok = GTK_FILE_SELECTION(FileSel)->ok_button;
	gtk_signal_connect(GTK_OBJECT(Ok), "clicked", GTK_SIGNAL_FUNC(OnSaveOther_Ok), NULL);
	gtk_widget_show(Ok);

	Cancel = GTK_FILE_SELECTION(FileSel)->cancel_button;
	gtk_signal_connect(GTK_OBJECT(Cancel), "clicked", GTK_SIGNAL_FUNC(OnSaveOther_Cancel), NULL);
	gtk_widget_show(Cancel);

	gtk_widget_show(FileSel);
	gdk_window_raise(FileSel->window);
}

bool SysInit()
{
	if (sinit) return true;
	sinit = true;

	mkdir(SSTATES_DIR, 0755);
	mkdir(MEMCARDS_DIR, 0755);

	mkdir(LOGS_DIR, 0755);

#ifdef PCSX2_DEVBUILD
	if (emuLog == NULL)
		emuLog = fopen(LOGS_DIR "/emuLog.txt", "wb");
#endif

	if (emuLog != NULL)
		setvbuf(emuLog, NULL, _IONBF, 0);

	PCSX2_MEM_PROTECT_BEGIN();
	SysDetect();
	if (!SysAllocateMem()) return false;	// critical memory allocation failure;

	SysAllocateDynarecs();
	PCSX2_MEM_PROTECT_END();

	while (LoadPlugins() == -1)
	{
		if (Pcsx2Configure() == FALSE)
		{
			Msgbox::Alert("Configuration failed. Exiting.");
			exit(1);
		}
	}

	return true;
}

void SysClose()
{
	if (sinit == false) return;
	cpuShutdown();
	ClosePlugins( true );
	ReleasePlugins();

	if (emuLog != NULL)
	{
		fclose(emuLog);
		emuLog = NULL;
	}
	sinit = false;
	
	// Precautionary extra shutdown stuff.
	SysEndExecution();
	g_EmulationInProgress = false;
}

namespace HostSys
{
	void *LoadLibrary(const char *lib)
	{
		return dlopen(lib, RTLD_NOW);
	}

	void *LoadSym(void *lib, const char *sym)
	{
		return dlsym(lib, sym);
	}

	const char *LibError()
	{
		return dlerror();
	}

	void CloseLibrary(void *lib)
	{
		dlclose(lib);
	}

	void *Mmap(uptr base, u32 size)
	{
		u8 *Mem;
		Mem = (u8*)mmap((uptr*)base, size, PROT_EXEC | PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, 0, 0);
		if (Mem == MAP_FAILED) Console::Notice("Mmap Failed!");

		return Mem;
	}

	void Munmap(uptr base, u32 size)
	{
		munmap((uptr*)base, size);
	}

	void MemProtect( void* baseaddr, size_t size, PageProtectionMode mode, bool allowExecution )
	{
		// Breakpoint this to trap potentially inappropriate use of page protection, which would
		// be caused by failed aligned directives on global vars.
		if( ((uptr)baseaddr & m_pagemask) != 0 )
		{
			Console::Error(
				"*PCSX2/Linux Warning* Inappropriate use of page protection detected.\n"
				"\tbaseaddr not page aligned: 0x%08X", params (uptr)baseaddr
			);
		}

		int lnxmode = 0;

		// make sure base and size are aligned to the system page size:
		size = (size + m_pagemask) & ~m_pagemask;
		baseaddr = (void*)( ((uptr)baseaddr) & ~m_pagemask );

		switch( mode )
		{
			case Protect_NoAccess: break;
			case Protect_ReadOnly: lnxmode = PROT_READ; break;
			case Protect_ReadWrite: lnxmode = PROT_READ | PROT_WRITE; break;
		}

		if( allowExecution ) lnxmode |= PROT_EXEC;
		mprotect( baseaddr, size, lnxmode );
	}
}

namespace HostGui
{
	// Sets the status bar message without mirroring the output to the console.
	void SetStatusMsg( const string& text )
	{
		// don't try this in Visual C++ folks!
		gtk_statusbar_push(GTK_STATUSBAR(pStatusBar), 0, text.c_str());
	}

	void Notice( const string& text )
	{
		// mirror output to the console!
		Console::Status( text.c_str() );
		SetStatusMsg( text );
	}

	void ResetMenuSlots()
	{
		for (int i = 0; i < 5; i++)
		{
			Slots[i] = States_isSlotUsed(i);
		}
	}

	void BeginExecution()
	{
		// Destroy the window.  Ugly thing.
		gtk_widget_destroy(MainWindow);
		gtk_main_quit();

		while (gtk_events_pending()) gtk_main_iteration();

		signal(SIGINT, SignalExit);
		signal(SIGPIPE, SignalExit);

		// no try/catch needed since no cleanup needed.. ?
		SysExecute();
	}

/* Quick macros for checking shift, control, alt, and caps lock. */
#define SHIFT_EVT(evt) ((evt == XK_Shift_L) || (evt == XK_Shift_R))
#define CTRL_EVT(evt) ((evt == XK_Control_L) || (evt == XK_Control_R))
#define ALT_EVT(evt) ((evt == XK_Alt_L) || (evt == XK_Alt_R))
#define CAPS_LOCK_EVT(evt) (evt == XK_Caps_Lock)

        void __fastcall KeyEvent(keyEvent* ev)
        {
		struct KeyModifiers *keymod = &keymodifiers;

                if (ev == NULL) return;

                if (GSkeyEvent != NULL) GSkeyEvent(ev);

                if (ev->evt == KEYPRESS)
                {
			if (SHIFT_EVT(ev->key)) keymod->shift = TRUE;
			if (CTRL_EVT(ev->key)) keymod->control = TRUE;
			if (ALT_EVT(ev->key)) keymod->alt = TRUE;
			if (CAPS_LOCK_EVT(ev->key)) keymod->capslock = TRUE;

                        switch (ev->key)
                        {
                                case XK_F1:
                                case XK_F2:
                                case XK_F3:
                                case XK_F4:
                                case XK_F5:
                                case XK_F6:
                                case XK_F7:
                                case XK_F8:
                                case XK_F9:
                                case XK_F10:
                                case XK_F11:
                                case XK_F12:
                                        try
                                        {
                                                ProcessFKeys(ev->key - XK_F1 + 1, keymod);
                                        }
                                        catch (Exception::CpuStateShutdown&)
                                        {
                                                // Woops!  Something was unrecoverable.  Bummer.
                                                // Let's give the user a RunGui!

                                                g_EmulationInProgress = false;
                                                SysEndExecution();
                                        }
                                        break;

                                case XK_Tab:
                                        CycleFrameLimit(0);
                                        break;

                                case XK_Escape:
                                        signal(SIGINT, SIG_DFL);
                                        signal(SIGPIPE, SIG_DFL);

        #ifdef PCSX2_DEVBUILD
                                        if (g_SaveGSStream >= 3)
                                        {
                                                g_SaveGSStream = 4;// gs state
                                                break;
                                        }
        #endif
                                        SysEndExecution();

                                        if (g_Startup.NoGui) exit(0);

                                        // fixme: The GUI is now capable of receiving control back from the
                                        // emulator.  Which means that when we call SysEscapeExecute() here, the
                                        // emulation loop in ExecuteCpu() will exit.  You should be able to set it
                                        // up so that it returns control to the existing GTK event loop, instead of
                                        // always starting a new one via RunGui().  (but could take some trial and
                                        // error)  -- (air)
                                        
                                        // Easier said then done; running gtk in two threads at the same time can't be
                                        // done, and working around that is pretty fiddly.
                                        RunGui();
                                        break;

                                default:
                                        GSkeyEvent(ev);
                                        break;
                        }
                }
                else if (ev->evt == KEYRELEASE)
                {
			if (SHIFT_EVT(ev->key)) keymod->shift = FALSE;
			if (CTRL_EVT(ev->key)) keymod->control = FALSE;
			if (ALT_EVT(ev->key)) keymod->alt = FALSE;
			if (CAPS_LOCK_EVT(ev->key)) keymod->capslock = FALSE;
                }

                return;
        }

}
