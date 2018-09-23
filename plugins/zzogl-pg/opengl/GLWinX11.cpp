/*  ZZ Open GL graphics plugin
 *  Copyright (c)2009-2010 zeydlitz@gmail.com, arcum42@gmail.com
 *  Based on Zerofrog's ZeroGS KOSMOS (c)2005-2008
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

#include "Util.h"
#include "GLWin.h"


// Need at least MESA 9.0 (plan for october/november 2012)
// So force the destiny to at least check the compilation
#ifndef EGL_KHR_create_context
#define EGL_KHR_create_context 1
#define EGL_CONTEXT_MAJOR_VERSION_KHR			    EGL_CONTEXT_CLIENT_VERSION
#define EGL_CONTEXT_MINOR_VERSION_KHR			    0x30FB
#define EGL_CONTEXT_FLAGS_KHR				    0x30FC
#define EGL_CONTEXT_OPENGL_PROFILE_MASK_KHR		    0x30FD
#define EGL_CONTEXT_OPENGL_RESET_NOTIFICATION_STRATEGY_KHR  0x31BD
#define EGL_NO_RESET_NOTIFICATION_KHR			    0x31BE
#define EGL_LOSE_CONTEXT_ON_RESET_KHR			    0x31BF
#define EGL_CONTEXT_OPENGL_DEBUG_BIT_KHR		    0x00000001
#define EGL_CONTEXT_OPENGL_FORWARD_COMPATIBLE_BIT_KHR	    0x00000002
#define EGL_CONTEXT_OPENGL_ROBUST_ACCESS_BIT_KHR	    0x00000004
#define EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT_KHR		    0x00000001
#define EGL_CONTEXT_OPENGL_COMPATIBILITY_PROFILE_BIT_KHR    0x00000002

bool GLWindow::CreateWindow(void *pDisplay)
{
	bool ret = true;

	glfwInit();

	// glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 2);
	// glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);
	window = glfwCreateWindow(640, 480, "My Title", NULL, NULL);
	glfwMakeContextCurrent(window);

	return ret;
}

bool GLWindow::ReleaseContext()
{
	return true;
}

void GLWindow::CloseWindow()
{
	SaveConfig();
}

void GLWindow::GetWindowSize()
{
	int width, height;

	glfwGetFramebufferSize(window, &width, &height);
	glViewport(0, 0, width, height);

    // update the gl buffer size
    UpdateWindowSize(width, height);

    ZZLog::Dev_Log("Resolution %dx%d.", width, height);
}


bool GLWindow::CreateContextGL()
{
	bool ret = true;
	return ret;
}

bool GLWindow::DisplayWindow(int _width, int _height)
{
	return true;
}
#endif

void GLWindow::SwapGLBuffers()
{
	if (glGetError() != GL_NO_ERROR) ZZLog::Debug_Log("glError before swap!");
	ZZLog::Check_GL_Error();

	glfwSwapBuffers(window);

	// glClear(GL_COLOR_BUFFER_BIT);
}

void GLWindow::InitVsync(bool extension)
{
}

void GLWindow::SetVsync(bool enable)
{
}

u32 THR_KeyEvent = 0; // Value for key event processing between threads
bool THR_bShift = false;
bool THR_bCtrl = false;

void GLWindow::ProcessEvents()
{
}


// ************************** Function that are useless in GSopen2 (GSopen 1 is only used with the debug replayer)
void GLWindow::SetTitle(char *strtitle) { }
