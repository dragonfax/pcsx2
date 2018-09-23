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

#ifndef GLWIN_H_INCLUDED
#define GLWIN_H_INCLUDED

#ifdef _WIN32
#define GL_WIN32_WINDOW
#define WGL_API

#else

#ifdef __APPLE__
#include <stdlib.h>
#include <unistd.h>
#include <GL/gl.h>
#include <GLFW/glfw3.h>

#else

#define GL_X11_WINDOW
#include <stdlib.h>
#include <X11/Xlib.h>

#ifdef EGL_API
#include <EGL/egl.h>
#include <EGL/eglext.h>

#else
#define GLX_API
#include <GL/glx.h>

#endif

#endif

#endif

// FIX compilation issue with Mesa 10
// Note it might be possible to do better with the right include 
// in the rigth order but I don't have time
#ifndef APIENTRY
#define APIENTRY
#endif
#ifndef APIENTRYP
#define APIENTRYP APIENTRY *
#endif

#undef CreateWindow	// Undo Windows.h global namespace pollution

#ifdef GLX_API
typedef void (APIENTRYP _PFNSWAPINTERVAL)(int);
#endif


extern void SetDeviceSize(int nNewWidth, int nNewHeight);
extern void OnFKey(int key, int shift);

class GLWindow
{
	private:
		void GetWindowSize();
		bool CreateContextGL(int, int);
		bool CreateContextGL();


		bool vsync_supported;

#ifdef __APPLE__
	GLFWwindow* window;
#endif

	public:
		char title[256];
		Size backbuffer;
		
		void SwapGLBuffers();
		bool ReleaseContext();

		bool CreateWindow(void *pDisplay);
		void CloseWindow();
		bool DisplayWindow(int _width, int _height);
		void SetTitle(char *strtitle);
		void ProcessEvents();

		void SetVsync(bool enable);
		void InitVsync(bool extension); // dummy in EGL
	
		void UpdateWindowSize(int nNewWidth, int nNewHeight)
		{
			FUNCLOG
			backbuffer.w = std::max(nNewWidth, 16);
			backbuffer.h = std::max(nNewHeight, 16);

			if (!(conf.fullscreen()))
			{
				conf.width = nNewWidth;
				conf.height = nNewHeight;
			}
		}

		
		GLWindow() {
		}
};

extern GLWindow GLWin;

#endif // GLWIN_H_INCLUDED
