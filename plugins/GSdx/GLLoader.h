/*
 *	Copyright (C) 2011-2014 Gregory hainaut
 *	Copyright (C) 2007-2009 Gabest
 *
 *  This Program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2, or (at your option)
 *  any later version.
 *
 *  This Program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with GNU Make; see the file COPYING.  If not, write to
 *  the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA USA.
 *  http://www.gnu.org/copyleft/gpl.html
 *
 */

#pragma once

#define GL_TEX_LEVEL_0 (0)
#define GL_TEX_LEVEL_1 (1)
#define GL_FB_DEFAULT  (0)
#define GL_BUFFER_0    (0)

#ifndef GL_CONTEXT_FLAG_NO_ERROR_BIT_KHR
#define GL_CONTEXT_FLAG_NO_ERROR_BIT_KHR  0x00000008
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

namespace GLLoader {
	void check_gl_requirements();

	extern bool vendor_id_amd;
	extern bool vendor_id_nvidia;
	extern bool vendor_id_intel;
	extern bool amd_legacy_buggy_driver;
	extern bool mesa_driver;
	extern bool buggy_sso_dual_src;
	extern bool in_replayer;

	// GL
	extern bool found_geometry_shader;
	extern bool found_GL_ARB_copy_image;
	extern bool found_GL_ARB_clip_control;
	extern bool found_GL_ARB_gpu_shader5;
	extern bool found_GL_ARB_shader_image_load_store;
	extern bool found_GL_ARB_clear_texture;
	extern bool found_GL_ARB_direct_state_access;
	extern bool found_GL_EXT_texture_filter_anisotropic;
	extern bool found_GL_NVX_gpu_memory_info;
	extern bool found_GL_ATI_meminfo;
}
