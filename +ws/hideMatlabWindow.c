#include "mex.h"
#include <windows.h>
/*
#include <stdio.h>
#include <process.h>
#include <string.h>
*/

BOOL CALLBACK EnumWindowsProc(HWND hwnd, LPARAM lParam)
    {
    unsigned long long hwndAsNumber ;
    HWND hwndOfOwner ;
    hwndAsNumber = (unsigned long long) hwnd ;
    //mexPrintf("One hwnd is %llu\n", hwndAsNumber) ;    
    hwndOfOwner = GetWindow(hwnd, GW_OWNER) ;
    //mexPrintf("  The hwnd of the owner of this window is %llu\n", (unsigned long long) hwndOfOwner) ;    
    if (!hwndOfOwner)  /* i.e. if hwndOfOwner is null */
        {
        /* If the owner is null, it must be the top-level window, which we want to hide */
        ShowWindow(hwnd, SW_HIDE) ;
        }
    return TRUE ; // TRUE means "keep enumerating the windows"
    }

void mexFunction( int nlhs, mxArray *plhs[], int nrhs, const mxArray*prhs[])  
    {
    DWORD threadID ;

    threadID = GetCurrentThreadId();
    EnumThreadWindows(threadID, EnumWindowsProc, 0) ;
    }

/*
    HWND hwnd ;
    unsigned long long hwndAsNumber ;    
    const unsigned int nTries = 10 ;
    const DWORD sleepDuration = 1000 ;
    unsigned int i ;

    for (i=0 ; i<nTries ; ++i)
        {
        hwnd = GetActiveWindow() ;
        hwndAsNumber = (unsigned long long) hwnd ;
        mexPrintf("The hwnd is %llu\n", hwndAsNumber) ;
        if (hwnd)
            {
            ShowWindow(hwnd, SW_HIDE) ;
            break ;
            }        
        Sleep(sleepDuration) ;
        }

    return ;
    }
*/
