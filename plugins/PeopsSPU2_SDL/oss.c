//Mess around with these to affect CPU load vs latency
#define BUFFSAMPLES (1024) //buffer size
#define LENGET (512) //Will play this much of the buffer before attempting to refresh it.
//According to the original oss.c, LENGET should be 1/2 of BUFFSAMPLES, however this probably isn't relevant anymore.

//Stuff that needs to stay from original oss.c
#include "stdafx.h"
#define _IN_OSS
#include "externals.h"
#include <sys/timeb.h>
extern unsigned int timeGetTime()
{
	struct timeb t;
	ftime(&t);
	return (unsigned int)(t.time*1000+t.millitm);
}
#define OSS_MEM_DEF
#include "oss.h"

#include <SDL/SDL.h>
#include <SDL/SDL_audio.h>
static Uint8 *audio_chunk;
static int audio_len=-1;

////////////////////////////////////////////////////////////////////////
// SETUP SOUND
////////////////////////////////////////////////////////////////////////

void SetupSound(void)
{
 int channels;
 if(iDisStereo) channels=1;
 else           channels=2;
    
    if (SDL_Init(SDL_INIT_AUDIO) < 0) {
        fprintf(stderr, "Unable to open audio: %s\n", SDL_GetError());
        return;
    }
    
    SDL_AudioSpec fmt;
    fmt.freq = 48000;
    fmt.format = AUDIO_S16LSB;  //SDL equivilent of AFMT_S16_LE
    fmt.channels = channels;
    fmt.samples = BUFFSAMPLES;
    void Callback(void *unused, Uint8 *stream, int len);
    fmt.callback = Callback;
    fmt.userdata = NULL;

    if ( SDL_OpenAudio(&fmt, NULL) < 0 ) {
        fprintf(stderr, "Unable to open audio: %s\n", SDL_GetError());
        return;
    }
    printf("Launching PeopsSPU2_SDL.\n");
    SDL_PauseAudio(0);
    audio_len=0;
}

void Callback(void *unused, Uint8 *stream, int len)
{
    if ( audio_len <= 0 )
        return;
    
    len = ( len > audio_len ? audio_len : len );
    memcpy(stream, audio_chunk, len);
    audio_chunk += len;
    audio_len -= len;
}

////////////////////////////////////////////////////////////////////////
// REMOVE SOUND
////////////////////////////////////////////////////////////////////////

void RemoveSound(void)
{
    audio_len=-1;
    SDL_CloseAudio();

    //SDL_Quit();
}

////////////////////////////////////////////////////////////////////////
// GET BYTES BUFFERED
////////////////////////////////////////////////////////////////////////

unsigned long SoundGetBytesBuffered(void)
{
    if(audio_len<LENGET) {
        return 0; //Write sound
    } else {
        return SOUNDSIZE; //Wait
    }
}

////////////////////////////////////////////////////////////////////////
// FEED SOUND DATA
////////////////////////////////////////////////////////////////////////

void SoundFeedVoiceData(unsigned char* pSound,long lBytes)
{
    if(audio_len == -1) return;
    audio_len=lBytes;
    audio_chunk=pSound;
}
