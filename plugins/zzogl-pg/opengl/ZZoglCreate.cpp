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

// Create and Destroy function. They would be called once per session.

//------------------ Includes
#include "GS.h"
#include "Mem.h"
#include "GLWin.h"
#include "ZZoglShaders.h"

#include "targets.h"
#include "rasterfont.h" // simple font
#include "ZZoglDrawing.h"
#include "ZZoglVB.h"

// This include for windows resource file with Shaders
#ifdef _WIN32
#	include "Win32.h"
#endif

// ----------------- Types
map<string, GLbyte> mapGLExtensions;

extern bool ZZshLoadExtraEffects();

GLuint vboRect = 0;
GLuint g_vboBuffers[VB_NUMBUFFERS]; // VBOs for all drawing commands
u32 g_nCurVBOIndex = 0;

inline bool CreateImportantCheck();
inline void CreateOtherCheck();
inline bool CreateOpenShadersFile();

void ZZGSStateReset();

//------------------ Dummies
#ifdef _WIN32
void __stdcall glBlendFuncSeparateDummy(GLenum e1, GLenum e2, GLenum e3, GLenum e4)
#else
void APIENTRY glBlendFuncSeparateDummy(GLenum e1, GLenum e2, GLenum e3, GLenum e4)
#endif
{
	glBlendFunc(e1, e2);
}

#ifdef _WIN32
void __stdcall glBlendEquationSeparateDummy(GLenum e1, GLenum e2)
#else
void APIENTRY glBlendEquationSeparateDummy(GLenum e1, GLenum e2)
#endif
{
	glBlendEquation(e1);
}

#ifdef _WIN32
extern HINSTANCE hInst;
void (__stdcall *zgsBlendEquationSeparate)(GLenum, GLenum) = NULL;
void (__stdcall *zgsBlendFuncSeparate)(GLenum, GLenum, GLenum, GLenum) = NULL;
#else
void (APIENTRY *zgsBlendEquationSeparate)(GLenum, GLenum) = NULL;
void (APIENTRY *zgsBlendFuncSeparate)(GLenum, GLenum, GLenum, GLenum) = NULL;
#endif

//------------------ variables
////////////////////////////
// State parameters

extern u8* s_lpShaderResources;

// String's for shader file in developer mode
//#ifdef ZEROGS_DEVBUILD
char EFFECT_NAME[256];
char EFFECT_DIR[256];
//#endif

/////////////////////
// graphics resources
GLenum s_srcrgb, s_dstrgb, s_srcalpha, s_dstalpha; // set by zgsBlendFuncSeparate
u32 s_stencilfunc, s_stencilref, s_stencilmask;
GLenum s_drawbuffers[] = { GL_COLOR_ATTACHMENT0_EXT, GL_COLOR_ATTACHMENT1_EXT };

u32 ptexLogo = 0;
int nLogoWidth, nLogoHeight;
u32 s_ptexInterlace = 0;		 // holds interlace fields
static bool vb_buffer_allocated = false;

//------------------ Global Variables
int GPU_TEXWIDTH = 512;
float g_fiGPU_TEXWIDTH = 1/512.0f;
int g_MaxTexWidth = 4096, g_MaxTexHeight = 4096;

namespace FB
{
	u32 buf = 0;
};

RasterFont* font_p = NULL;
float g_fBlockMult = 1;
//int s_nFullscreen = 0;

u32 ptexBlocks = 0, ptexConv16to32 = 0;	 // holds information on block tiling
u32 ptexBilinearBlocks = 0;
u32 ptexConv32to16 = 0;
// int g_nDepthBias = 0;

extern void Delete_Avi_Capture();
extern void ZZDestroy();
extern void SetAA(int mode);

//------------------ Code

///< returns true if the the opengl extension is supported
/*
bool IsGLExt(const char* szTargetExtension)
{
	return mapGLExtensions.find(string(szTargetExtension)) != mapGLExtensions.end();
}
*/

inline bool check_gl_version(uint32 major, uint32 minor) {
	const GLubyte* s;
	s = glGetString(GL_VERSION);
	if (s == NULL) return false;
	ZZLog::Error_Log("Supported Opengl version: %s on GPU: %s. Vendor: %s\n", s, glGetString(GL_RENDERER), glGetString(GL_VENDOR));
	// Could be useful to detect the GPU vendor:
	// if ( strcmp((const char*)glGetString(GL_VENDOR), "ATI Technologies Inc.") == 0 )

	GLuint dot = 0;
	while (s[dot] != '\0' && s[dot] != '.') dot++;
	if (dot == 0) return false;

	GLuint major_gl = s[dot-1]-'0';
	GLuint minor_gl = s[dot+1]-'0';

	if ( (major_gl < major) || ( major_gl == major && minor_gl < minor ) ) {
		ZZLog::Error_Log("OPENGL %d.%d is not supported\n", major, minor);
		return false;
	}

	return true;
}

// Function asks about different OGL extensions, that are required to setup accordingly. Return false if checks failed
inline bool CreateImportantCheck()
{
	bool bSuccess = true;
	glewInit();

#ifndef _WIN32
	int const glew_ok = glewInit();

	if (glew_ok != GLEW_OK) {
		ZZLog::Error_Log("glewInit() is not ok!");
		// Better exit now, any openGL call will segfault.
		return false;
	}
#endif

	// Require a minimum of openGL2.0 (first version that support hardware shader)
	bSuccess &= check_gl_version(2, 0);

	// GL_EXT_framebuffer_object -> GL3.0
	// Opensource driver -> Intel OK. Radeon need EXT_packed_depth_stencil
	/*
	if (!IsGLExt("GL_EXT_framebuffer_object"))
	{
		ZZLog::Error_Log("*********\nZZogl: ERROR: Need GL_EXT_framebuffer_object for multiple render targets\nZZogl: *********");
		bSuccess = false;
	}
	*/

	bSuccess &= ZZshCheckProfilesSupport();
	
	return bSuccess;
}

// This is a check for less important open gl extensions.
inline void CreateOtherCheck()
{
	// GL_EXT_blend_equation_separate -> GL2.0
	// Opensource driver -> Intel OK. Radeon OK.
	zgsBlendEquationSeparate = glBlendEquationSeparate;

	// GL_EXT_blend_func_separate -> GL1.4
	// Opensource driver -> Intel OK. Radeon OK.
	zgsBlendFuncSeparate = glBlendFuncSeparate;

	// GL_ARB_draw_buffers -> GL2.0
	// Opensource driver -> Intel (need gen4). Radeon OK.
	if (glDrawBuffers == NULL) {
		ZZLog::Error_Log("*********\nZZogl: OGL ERROR: multiple render targets not supported, some effects might look bad\nZZogl: *********");
		conf.mrtdepth = 0;
	}

	GLint Max_Texture_Size_NV = 0;
	GLint Max_Texture_Size_2d = 0;

	glGetIntegerv(GL_MAX_RECTANGLE_TEXTURE_SIZE_NV, &Max_Texture_Size_NV);
	glGetIntegerv(GL_MAX_TEXTURE_SIZE, &Max_Texture_Size_2d);

	g_MaxTexHeight = min(Max_Texture_Size_2d, Max_Texture_Size_NV);

	ZZLog::Error_Log("Maximum texture size is %d for Tex_2d and %d for Tex_NV.", Max_Texture_Size_2d, Max_Texture_Size_NV);

	if (Max_Texture_Size_NV < 1024)
		ZZLog::Error_Log("Could not properly make bitmasks, so some textures will be missed.");

#ifdef _WIN32
	GLWin.InitVsync(IsGLExt("WGL_EXT_swap_control") || IsGLExt("EXT_swap_control"));
#else
	GLWin.InitVsync(1); // IsGLExt("GLX_SGI_swap_control"));
#endif

	GLWin.SetVsync(false);
}


#ifdef _WIN32
__forceinline bool LoadShadersFromRes()
{
	HRSRC hShaderSrc = FindResource(hInst, MAKEINTRESOURCE(IDR_SHADERS), RT_RCDATA);
	assert(hShaderSrc != NULL);
	HGLOBAL hShaderGlob = LoadResource(hInst, hShaderSrc);
	assert(hShaderGlob != NULL);
	s_lpShaderResources = (u8*)LockResource(hShaderGlob);
	return true;
}
#else

__forceinline bool LoadShadersFromDat()
{
	FILE* fres = fopen("ps2hw.dat", "rb");

	if (fres == NULL)
	{
		fres = fopen("plugins/ps2hw.dat", "rb");

		if (fres == NULL)
		{
			// Each linux distributions have his rules for path so we give them the possibility to
			// change it with compilation flags. -- Gregory
#ifdef PLUGIN_DIR_COMPILATION
#define xPLUGIN_DIR_str(s) PLUGIN_DIR_str(s)
#define PLUGIN_DIR_str(s) #s
			const std::string shader_file = string(xPLUGIN_DIR_str(PLUGIN_DIR_COMPILATION)) + "/ps2hw.dat";
			fres = fopen(shader_file.c_str(), "rb");
#endif
			if (fres == NULL)
			{
				ZZLog::Error_Log("Cannot find ps2hw.dat in working directory. Exiting.");
				return false;
			}
		}
	}

	fseek(fres, 0, SEEK_END);

	size_t s = ftell(fres);
	s_lpShaderResources = new u8[s+1];
	fseek(fres, 0, SEEK_SET);
	if (fread(s_lpShaderResources, s, 1, fres) == 0)
		fprintf(stderr, "Failed to read ps2hw.dat. Corrupted file?\n");

	s_lpShaderResources[s] = 0;
	fclose(fres);

	return true;
}

#ifdef DEVBUILD
__forceinline bool LoadShadersFromFX()
{
	// test if ps2hw.fx exists
	char tempstr[255];
	char curwd[255];
	getcwd(curwd, ArraySize(curwd));

	strcpy(tempstr, "/plugins/");
	sprintf(EFFECT_NAME, "%sps2hw.fx", tempstr);
	FILE* f = fopen(EFFECT_NAME, "r");

	if (f == NULL)
	{

		strcpy(tempstr, "../../plugins/zzogl-pg/opengl/");
		sprintf(EFFECT_NAME, "%sps2hw.fx", tempstr);
		f = fopen(EFFECT_NAME, "r");

		if (f == NULL)
		{
			ZZLog::Error_Log("Failed to find %s, try compiling a non-devbuild.", EFFECT_NAME);
			return false;
		}
	}

	fclose(f);

	sprintf(EFFECT_DIR, "%s/%s", curwd, tempstr);
	sprintf(EFFECT_NAME, "%sps2hw.fx", EFFECT_DIR);
	
	return true;
}
#endif
#endif


// open shader file according to build target

inline bool CreateOpenShadersFile()
{
#ifndef DEVBUILD
#	ifdef _WIN32
	return LoadShadersFromRes();
#	else // not _WIN32
	return LoadShadersFromDat();
#	endif // _WIN32
#else // defined(ZEROGS_DEVBUILD)
#	ifndef _WIN32 // NOT WINDOWS
	return LoadShadersFromFX();
	
	// No else clause?
#endif
#endif // !defined(ZEROGS_DEVBUILD)
}

// Read all extensions name and fill mapGLExtensions
/*
inline bool CreateFillExtensionsMap()
{
    int max_ext = 0;
	string all_ext("");

	// PFNGLGETSTRINGIPROC glGetStringi = 0;
	glGetIntegerv(GL_NUM_EXTENSIONS, &max_ext);

    if (glGetStringi && max_ext) {
        // Get opengl extension (opengl3)
        for (GLint i = 0; i < max_ext; i++)
        {
            string extension((const char*)glGetStringi(GL_EXTENSIONS, i));
            mapGLExtensions[extension];

            all_ext += extension;
            if (i != (max_ext - 1)) all_ext += ", ";
        }
    } else {
        // fallback to old method (pre opengl3, intel gma, geforce 7 ...)
        ZZLog::Error_Log("glGetStringi opengl 3 interface not supported, fallback to opengl 2");

        const char* ptoken = (const char*)glGetString(GL_EXTENSIONS);
        if (ptoken == NULL) return false;

        all_ext = string(ptoken); // save the string to print a nice debug message

        const char* pend = NULL;
        while (ptoken != NULL)
        {
            pend = strchr(ptoken, ' ');

            if (pend != NULL)
            {
                max_ext++;
                mapGLExtensions[string(ptoken, pend-ptoken)];
            }
            else
            {
                max_ext++;
                mapGLExtensions[string(ptoken)];
                break;
            }

            ptoken = pend;
            while (*ptoken == ' ') ++ptoken;
        }
    }


#ifndef _DEBUG
	ZZLog::Log("%d supported OpenGL Extensions: %s\n", max_ext, all_ext.c_str());
#endif
	ZZLog::Debug_Log("%d supported OpenGL Extensions: %s\n", max_ext, all_ext.c_str());
	
	return true;
}
*/


inline bool TryBlockFormat(GLint fmt, const GLvoid* vBlockData) {
	glTexImage2D(GL_TEXTURE_2D, 0, fmt, BLOCK_TEXWIDTH, BLOCK_TEXHEIGHT, 0, GL_ALPHA, GL_FLOAT, vBlockData);
	return (glGetError() == GL_NO_ERROR);
}

inline bool TryBlinearFormat(GLint fmt32, const GLvoid* vBilinearData) {
	glTexImage2D(GL_TEXTURE_2D, 0, fmt32, BLOCK_TEXWIDTH, BLOCK_TEXHEIGHT, 0, GL_RGBA, GL_FLOAT, vBilinearData);
	return (glGetError() == GL_NO_ERROR);
}

bool ZZCreate(int _width, int _height)
{
	GLenum err = GL_NO_ERROR;
	bool bSuccess = true;

	ZZDestroy();
	ZZGSStateReset();
	
	if (!GLWin.DisplayWindow(_width, _height)) return false;

	conf.mrtdepth = 0; // for now

	// if (!CreateFillExtensionsMap()) return false;
	if (!CreateImportantCheck()) return false;

	CreateOtherCheck();

	// Incorrect must check rectangle texture too. Now done directly on CreateOtherCheck()
	//
	// check the max texture width and height
	///glGetIntegerv(GL_MAX_TEXTURE_SIZE, &g_MaxTexWidth);
    // Limit the texture size supported to 8192. We do not need bigger texture.
    // Besides the following assertion is false when texture are too big.
    // ZZoglFlush.cpp:2349:	assert(fblockstride >= 1.0f)
    //g_MaxTexWidth = min(8192, g_MaxTexWidth);

	g_MaxTexHeight = g_MaxTexWidth / 4;
	GPU_TEXWIDTH = min (g_MaxTexWidth/8, 1024);
	g_fiGPU_TEXWIDTH = 1.0f / GPU_TEXWIDTH;

#if !(defined(GLSL_API) || defined(GLSL4_API))
	if (!CreateOpenShadersFile()) return false;
#endif

	GL_REPORT_ERROR();

	if (err != GL_NO_ERROR) bSuccess = false;

	s_srcrgb = s_dstrgb = s_srcalpha = s_dstalpha = GL_ONE;

	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
	GL_REPORT_ERROR();

	if (err != GL_NO_ERROR) bSuccess = false;

	FB::Create();

	GL_REPORT_ERRORD();

	FB::Bind();

	DrawBuffers(s_drawbuffers);
		
	GL_REPORT_ERROR();

	if (err != GL_NO_ERROR) bSuccess = false;

	font_p = new RasterFont();
	GL_REPORT_ERROR();

	if (err != GL_NO_ERROR) bSuccess = false;

	// init draw fns
	//init_drawfn();
	if (ZZKick != NULL) delete ZZKick;
	ZZKick = new Kick;
	
	SetAA(conf.aa);

	GSsetGameCRC(g_LastCRC, conf.settings()._u32);

	GL_STENCILFUNC(GL_ALWAYS, 0, 0);

	//s_bWriteDepth = true;

	GL_BLEND_ALL(GL_ONE, GL_ONE, GL_ONE, GL_ONE);
	glViewport(0, 0, GLWin.backbuffer.w, GLWin.backbuffer.h);					 // Reset The Current Viewport
	
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	
	glShadeModel(GL_SMOOTH);
	glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
	glClearDepth(1.0f);
	
	glEnable(GL_DEPTH_TEST);
	glDisable(GL_LIGHTING);
	
	glDepthFunc(GL_LEQUAL);
	glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);  // Really Nice Perspective Calculations
	glGenTextures(1, &ptexLogo);
	glBindTexture(GL_TEXTURE_RECTANGLE_NV, ptexLogo);

#ifdef _WIN32
	HRSRC hBitmapSrc = FindResource(hInst, MAKEINTRESOURCE(IDB_ZEROGSLOGO), RT_BITMAP);
	assert(hBitmapSrc != NULL);

	HGLOBAL hBitmapGlob = LoadResource(hInst, hBitmapSrc);
	assert(hBitmapGlob != NULL);

	PBITMAPINFO pinfo = (PBITMAPINFO)LockResource(hBitmapGlob);

	GLenum tempFmt = (pinfo->bmiHeader.biBitCount == 32) ? GL_RGBA : GL_RGB;
	TextureRect(GL_RGBA, pinfo->bmiHeader.biWidth, pinfo->bmiHeader.biHeight, tempFmt, GL_UNSIGNED_BYTE, (u8*)pinfo + pinfo->bmiHeader.biSize);

	nLogoWidth = pinfo->bmiHeader.biWidth;
	nLogoHeight = pinfo->bmiHeader.biHeight;

	setRectFilters(GL_LINEAR);

#else
#endif

	GL_REPORT_ERROR();

#ifdef GLSL4_API
	GSInputLayoutOGL vert_format[] =
	{
		{0 , 4 , GL_SHORT , GL_FALSE , sizeof(VertexGPU) , (const GLvoid*)(0) }  , // vertex
		{1 , 4 , GL_UNSIGNED_BYTE  , GL_TRUE  , sizeof(VertexGPU) , (const GLvoid*)(8) }  , // color
		{2 , 4 , GL_UNSIGNED_BYTE  , GL_TRUE , sizeof(VertexGPU) , (const GLvoid*)(12) } , // z value. FIXME WTF 4 unsigned byte, why not a full integer
		{3 , 3 , GL_FLOAT          , GL_FALSE , sizeof(VertexGPU) , (const GLvoid*)(16) } , // tex coord
	};

	vertex_array = new GSVertexBufferStateOGL(sizeof(VertexGPU), vert_format, 4);
#endif

	g_nCurVBOIndex = 0;

    if (!vb_buffer_allocated) {
        glGenBuffers((GLsizei)ArraySize(g_vboBuffers), g_vboBuffers);
        for (u32 i = 0; i < ArraySize(g_vboBuffers); ++i)
        {
            glBindBuffer(GL_ARRAY_BUFFER, g_vboBuffers[i]);
            glBufferData(GL_ARRAY_BUFFER, 0x100*sizeof(VertexGPU), NULL, GL_STREAM_DRAW);
#ifdef GLSL4_API
			vertex_array->set_internal_format();
#endif
        }
        vb_buffer_allocated = true; // mark the buffer allocated
    }

	GL_REPORT_ERROR();
	if (err != GL_NO_ERROR) bSuccess = false;

	// create the blocks texture
	g_fBlockMult = 1;

#ifndef ZZNORMAL_MEMORY
	FillAlowedPsnTable();
	FillBlockTables();
#endif

	vector<char> vBlockData, vBilinearData;
	BLOCK::FillBlocks(vBlockData, vBilinearData);

	// clear errors
	while ( glGetError() != GL_NO_ERROR) {

	}

	glGenTextures(1, &ptexBlocks);
	err = glGetError();
	if (err != GL_NO_ERROR) {
		ZZLog::Error_Log("ZZogl ERROR: could not gen texture (%d)", err);
	}
	if (ptexBlocks == 0 ) {
		ZZLog::Error_Log("generated texture number 0");
	}

	glBindTexture(GL_TEXTURE_2D, ptexBlocks);
	err = glGetError();
	if (err != GL_NO_ERROR) {
		ZZLog::Error_Log("ZZogl ERROR: could not bind texture (%d)", err);
	}
	
	// Opensource driver -> Intel (need gen4) (enabled by default on mesa 9). Radeon depends on the HW capability
#ifdef GLSL4_API
	// texture float -> GL3.0
	glTexImage2D(GL_TEXTURE_2D, 0, GL_R32F, BLOCK_TEXWIDTH, BLOCK_TEXHEIGHT, 0, GL_RED, GL_FLOAT, &vBlockData[0]);
	err = glGetError();
	if (err != GL_NO_ERROR) {
		ZZLog::Error_Log("ZZogl ERROR: could not fill blocks (%d)", err);
		return false;
	}
#else
	if 	(TryBlockFormat(GL_RGBA32F, &vBlockData[0]))
		ZZLog::Error_Log("Use GL_RGBA32F for blockdata.");
	else if (TryBlockFormat(GL_ALPHA_FLOAT32_ATI, &vBlockData[0]))
	 	ZZLog::Error_Log("Use ATI_texture_float for blockdata.");
	else {
		ZZLog::Error_Log("ZZogl ERROR: float texture not supported. If you use opensource driver (aka Mesa), you probably need to compile it with texture float support.");
		ZZLog::Error_Log("ZZogl ERROR: Otherwise you probably have a very very old GPU, either use an older version of the plugin or upgrade your computer");
		return false;
	}
#endif

	setTex2DFilters(GL_NEAREST);
	setTex2DWrap(GL_REPEAT);

	err = glGetError();
	if (err != GL_NO_ERROR) {
		ZZLog::Error_Log("ZZogl ERROR: 1 (%d)", err);
	}

	// fill in the bilinear blocks (main variant).
	glGenTextures(1, &ptexBilinearBlocks);
	glBindTexture(GL_TEXTURE_2D, ptexBilinearBlocks);

	err = glGetError();
	if (err != GL_NO_ERROR) {
		ZZLog::Error_Log("ZZogl ERROR: 2 (%d)", err);
	}

#ifdef GLSL4_API
	if 	(!TryBlinearFormat(GL_RGBA32F, &vBilinearData[0]))
		ZZLog::Error_Log("Fill bilinear blocks failed.");
#else
	if 	(TryBlinearFormat(GL_RGBA32F, &vBilinearData[0]))
		ZZLog::Error_Log("Fill bilinear blocks OK.!");
	else if (TryBlinearFormat(GL_RGBA_FLOAT32_ATI, &vBilinearData[0]))
		ZZLog::Error_Log("Fill bilinear blocks with ATI_texture_float.");
	else if (TryBlinearFormat(GL_FLOAT_RGBA32_NV, &vBilinearData[0]))
		ZZLog::Error_Log("ZZogl Fill bilinear blocks with NVidia_float.");
	else
		ZZLog::Error_Log("Fill bilinear blocks failed.");
#endif

	setTex2DFilters(GL_NEAREST);
	setTex2DWrap(GL_REPEAT);

	err = glGetError();
	while ( err != GL_NO_ERROR ) {
		ZZLog::Error_Log("ZZogl ERROR: (%d)", err);
		err = glGetError();
	}

/*
	float fpri = 1;

	glPrioritizeTextures(1, &ptexBlocks, &fpri);

	err = glGetError();
	if (err != GL_NO_ERROR) {
		ZZLog::Error_Log("ZZogl ERROR: glPrioritizeTextures (%d)", err);
	}

	if (ptexBilinearBlocks != 0) {
		glPrioritizeTextures(1, &ptexBilinearBlocks, &fpri);
		err = glGetError();
		if (err != GL_NO_ERROR) {
			ZZLog::Error_Log("ZZogl ERROR: glPrioritizeTextures again (%d)", err);
		}
	}


	GL_REPORT_ERROR();
	*/	

	// fill a simple rect
	glGenBuffers(1, &vboRect);
	err = glGetError();
	if (err != GL_NO_ERROR) {
		ZZLog::Error_Log("ZZogl ERROR: glGenBuffers (%d)", err);
	}
		
	glBindBuffer(GL_ARRAY_BUFFER, vboRect);
	err = glGetError();
	if (err != GL_NO_ERROR) {
		ZZLog::Error_Log("ZZogl ERROR: glBindBuffer (%d)", err);
	}

#ifdef GLSL4_API
	vertex_array->set_internal_format();
	err = glGetError();
	if (err != GL_NO_ERROR) {
		ZZLog::Error_Log("ZZogl ERROR: set_internal_format (%d)", err);
	}
#endif

	vector<VertexGPU> verts(4);

	VertexGPU* pvert = &verts[0];

	pvert->set_xyzst(-0x7fff, 0x7fff, 0, 0, 0);
	pvert++;

	pvert->set_xyzst(0x7fff, 0x7fff, 0, 1, 0);
	pvert++;

	pvert->set_xyzst(-0x7fff, -0x7fff, 0, 0, 1);
	pvert++;

	pvert->set_xyzst(0x7fff, -0x7fff, 0, 1, 1);
	pvert++;

	glBufferData(GL_ARRAY_BUFFER, 4*sizeof(VertexGPU), &verts[0], GL_STATIC_DRAW);

	err = glGetError();
	if (err != GL_NO_ERROR) {
		ZZLog::Error_Log("ZZogl ERROR: 5 (%d)", err);
	}

#ifndef GLSL4_API
	// setup the default vertex declaration
	glEnableClientState(GL_VERTEX_ARRAY);
	glClientActiveTexture(GL_TEXTURE0);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glEnableClientState(GL_SECONDARY_COLOR_ARRAY);
	glEnableClientState(GL_COLOR_ARRAY);
	GL_REPORT_ERROR();
#endif

	// create the conversion textures
	glGenTextures(1, &ptexConv16to32);
	glBindTexture(GL_TEXTURE_2D, ptexConv16to32);

	err = glGetError();
	if (err != GL_NO_ERROR) {
		ZZLog::Error_Log("ZZogl ERROR: 6 (%d)", err);
	}

	vector<u32> conv16to32data(256*256);

	for (int i = 0; i < 256*256; ++i)
	{
		u32 tempcol = RGBA16to32(i);
		// have to flip r and b
		conv16to32data[i] = (tempcol & 0xff00ff00) | ((tempcol & 0xff) << 16) | ((tempcol & 0xff0000) >> 16);
	}

	Texture2D(4, 256, 256, GL_RGBA, GL_UNSIGNED_BYTE, &conv16to32data[0]);

	setTex2DFilters(GL_NEAREST);
	setTex2DWrap(GL_CLAMP);

	GL_REPORT_ERROR();

	if (err != GL_NO_ERROR) {
		bSuccess = false;
		ZZLog::Error_Log("got a gl error earlier");
	}

	vector<u32> conv32to16data(32*32*32);

	glGenTextures(1, &ptexConv32to16);

	glBindTexture(GL_TEXTURE_3D, ptexConv32to16);

	u32* dst = &conv32to16data[0];

	for (int i = 0; i < 32; ++i)
	{
		for (int j = 0; j < 32; ++j)
		{
			for (int k = 0; k < 32; ++k)
			{
				u32 col = (i << 10) | (j << 5) | k;
				*dst++ = ((col & 0xff) << 16) | (col & 0xff00);
			}
		}
	}

	Texture3D(4, 32, 32, 32, GL_RGBA, GL_UNSIGNED_BYTE, &conv32to16data[0]);
	setTex3DFilters(GL_NEAREST);
	setTex3DWrap(GL_CLAMP);
	GL_REPORT_ERROR();

	if (err != GL_NO_ERROR) bSuccess = false;

	if (!ZZshStartUsingShaders()) {
		bSuccess = false;
		ZZLog::Error_Log("ZZshStartUsingShaders error");
	}

	GL_REPORT_ERROR();


	if (err != GL_NO_ERROR) {
		bSuccess = false;
		ZZLog::Error_Log("got a gl error somewhere");
	}

	glDisable(GL_STENCIL_TEST);
	err = glGetError();
	if ( err != GL_NO_ERROR ) {
		ZZLog::Error_Log("glDisable Stencil %d", err);
	}
	glEnable(GL_SCISSOR_TEST);
	err = glGetError();
	if ( err != GL_NO_ERROR ) {
		ZZLog::Error_Log("glEnable Scisors");
	}

	GL_BLEND_ALPHA(GL_ONE, GL_ZERO);
	err = glGetError();
	if ( err != GL_NO_ERROR ) {
		ZZLog::Error_Log("GL_BLEND_ALPHA");
	}

	glBlendColor(0, 0, 0, 0.5f);
	err = glGetError();
	if ( err != GL_NO_ERROR ) {
		ZZLog::Error_Log("glBlendColor");
	}

	glDisable(GL_CULL_FACE);
	err = glGetError();
	if ( err != GL_NO_ERROR ) {
		ZZLog::Error_Log("glDisable Cullface");
	}

	// points
	// This was changed in SetAA - should we be changing it back?
	glPointSize(1.0f);
	err = glGetError();
	if ( err != GL_NO_ERROR ) {
		ZZLog::Error_Log("glPoitnSize");
	}

	// g_nDepthBias = 0;

	glEnable(GL_POLYGON_OFFSET_FILL);
	err = glGetError();
	if ( err != GL_NO_ERROR ) {
		ZZLog::Error_Log("glEnablePolygon");
	}

	glEnable(GL_POLYGON_OFFSET_LINE);
	err = glGetError();
	if ( err != GL_NO_ERROR ) {
		ZZLog::Error_Log("glEnablePolygon");
	}

	glPolygonOffset(0, 1);

	err = glGetError();
	if ( err != GL_NO_ERROR ) {
		ZZLog::Error_Log("glPolygonOffset");
	}

	vb[0].Init(VB_BUFFERSIZE);
	vb[1].Init(VB_BUFFERSIZE);

	g_vsprog = g_psprog = sZero;

	if (glGetError() == GL_NO_ERROR)
	{
		return bSuccess;
	}
	else
	{
		ZZLog::Error_Log("final error");
		ZZLog::Debug_Log("Error In final init!");
		return false;
	}
}

void ZZDestroy()
{
	Delete_Avi_Capture();

	g_MemTargs.Destroy();

	s_RTs.Destroy();
	s_DepthRTs.Destroy();
	s_BitwiseTextures.Destroy();

	SAFE_RELEASE_TEX(s_ptexInterlace);
	SAFE_RELEASE_TEX(ptexBlocks);
	SAFE_RELEASE_TEX(ptexBilinearBlocks);
	SAFE_RELEASE_TEX(ptexConv16to32);
	SAFE_RELEASE_TEX(ptexConv32to16);

	vb[0].Destroy();
	vb[1].Destroy();

	if (vb_buffer_allocated)
	{
		glDeleteBuffers((GLsizei)ArraySize(g_vboBuffers), g_vboBuffers);
        vb_buffer_allocated = false; // mark the buffer unallocated
	}

#ifdef GLSL4_API
	if (vertex_array != NULL) {
		delete vertex_array;
		vertex_array = NULL;
	}
#endif

	g_nCurVBOIndex = 0;
	
	for (u32 i = 0; i < ArraySize(pvs); ++i)
	{
		SAFE_RELEASE_PROG(pvs[i]);
	}

	for (u32 i = 0; i < ArraySize(ppsRegular); ++i)
	{
		SAFE_RELEASE_PROG(ppsRegular[i].prog);
	}

	for (u32 i = 0; i < ArraySize(ppsTexture); ++i)
	{
		SAFE_RELEASE_PROG(ppsTexture[i].prog);
	}

	SAFE_RELEASE_PROG(pvsBitBlt.prog);

	SAFE_RELEASE_PROG(ppsBitBlt[0].prog);
	SAFE_RELEASE_PROG(ppsBitBlt[1].prog);
	SAFE_RELEASE_PROG(ppsBitBltDepth.prog);
	SAFE_RELEASE_PROG(ppsCRTCTarg[0].prog);
	SAFE_RELEASE_PROG(ppsCRTCTarg[1].prog);
	SAFE_RELEASE_PROG(ppsCRTC[0].prog);
	SAFE_RELEASE_PROG(ppsCRTC[1].prog);
//	SAFE_RELEASE_PROG(ppsCRTC24[0].prog);
//	SAFE_RELEASE_PROG(ppsCRTC24[1].prog);
	SAFE_RELEASE_PROG(ppsOne.prog);

	safe_delete(font_p);

	FB::Delete();

	GLWin.ReleaseContext();

	mapGLExtensions.clear();
}

