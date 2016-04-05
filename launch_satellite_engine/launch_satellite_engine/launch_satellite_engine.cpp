#include <windows.h>
#include <stdio.h>
#include <io.h>
#include <fcntl.h>
#include <string>
#include "engine.h"
#include <iostream>
#include "utility.hpp"

int WINAPI wWinMain (HINSTANCE hInstance,
                     HINSTANCE hPrevInstance,
                     LPWSTR    lpszCmdLine,
                     int       nCmdShow)
    {
    // Report that we are alive
    //OutputDebugString(L"Inside launch_satellite_engine.exe\n");

    // Want a console for printf's
    AllocConsole();

    HANDLE handle_out = GetStdHandle(STD_OUTPUT_HANDLE);
    int hCrt = _open_osfhandle((long) handle_out, _O_TEXT);
    FILE* hf_out = _fdopen(hCrt, "w");
    setvbuf(hf_out, NULL, _IONBF, 1);
    *stdout = *hf_out;

    HANDLE handle_in = GetStdHandle(STD_INPUT_HANDLE);
    hCrt = _open_osfhandle((long) handle_in, _O_TEXT);
    FILE* hf_in = _fdopen(hCrt, "r");
    setvbuf(hf_in, NULL, _IONBF, 128);
    *stdin = *hf_in;
    // use the console just like a normal one - printf(), getchar(), ...

    //printf("Hello, world!\n") ;

    //std::cout << "Hello, world!" << std::endl ;

    //system("pause");

    // Process the command-line args
    std::wstring args = lpszCmdLine ;
    std::wstring looper_or_refiller, matlab_bin_path, path_to_repo_root, path_to_matlab_zmq_lib, visible_or_invisible ;
    try
        {
        looper_or_refiller      = extract_single_argument(args, 0) ;
        }
    catch (std::domain_error)
        {
        exit(-1) ;
        }

    try
        {
        matlab_bin_path         = extract_single_argument(args, 1) ;
        }
    catch (std::domain_error)
        {
        exit(-2) ;
        }

    try
        {
        path_to_repo_root       = extract_single_argument(args, 2) ;
        }
    catch (std::domain_error)
        {
        exit(-3) ;
        }

    try
        {
        path_to_matlab_zmq_lib  = extract_single_argument(args, 3) ;
        }
    catch (std::domain_error)
        {
        exit(-4) ;
        }

    try
        {
        visible_or_invisible    = extract_single_argument(args, 4) ;
        }
    catch (std::domain_error)
        {
        exit(-5) ;
        }
 
    //system("pause");
    std::cout << "Successfully read all the input arguments:" << std::endl ;
    std::wcout << L"    visible_or_invisible: " << visible_or_invisible << std::endl ;

    // Get the path
    std::wstring original_path ;
    try
        {
        original_path = GetEnvironmentVariableGracefully(std::wstring(L"Path")) ;
        }
    catch ( std::runtime_error )
        {
        MessageBox((HWND)NULL, (LPCWSTR) L"Unable to read Path environment variable", 
                   (LPCWSTR) L"Boo", MB_OK) ;
        exit(-1) ;
        }

    // Construct the new path
    std::wstring new_path = matlab_bin_path + L";" + original_path ;

    // Set the env var to the new path
    int didSucceed = SetEnvironmentVariable(L"Path", new_path.c_str()) ;
    if (!didSucceed)
        {
        exit(-1) ;
        }

    // Get the path again, to check it
    /*
    std::wstring new_path_check ;
    try
        {
        new_path_check = GetEnvironmentVariableGracefully(std::wstring(L"Path")) ;
        }
    catch ( std::runtime_error )
        {
        MessageBox((HWND)NULL, (LPCWSTR) L"Unable to read Path environment variable to check it", 
                   (LPCWSTR) L"Boo", MB_OK) ;
        exit(-1) ;
        }

    // Show the new path
    MessageBox((HWND)NULL, (LPCWSTR) new_path_check.c_str(), 
               (LPCWSTR) L"Path, after", MB_OK) ;
    */

    //system("pause");

    /*
     * Start the MATLAB engine 
     */
    Engine *ep ;
    if (!(ep = engOpen(NULL))) 
        {
        MessageBox((HWND)NULL, (LPCWSTR) L"Can't start MATLAB engine", 
                   (LPCWSTR) L"Boo", MB_OK);
        exit(-1);
        }

    // Make the command window invisible
    if ( looper_or_refiller == std::wstring(L"invisible") )
        {
        engSetVisible(ep, 0);
        }
    else
        {
        engSetVisible(ep, 1);
        }

    // Execute the commands that will start the satellite main loop
    //"addpath(''%s''); addpath(''%s''); looper=ws.Looper(); looper.runMainLoop(); clear; quit()"
    std::wstring wide_command_string ;
    std::string command_string ;

    //system("pause");

    // Add the WS root to the path
    wide_command_string = std::wstring(L"addpath('") + path_to_repo_root + L"');" ;
    command_string = utf8_encode(wide_command_string) ;
    engEvalString(ep, command_string.c_str());

    //system("pause");

    // Add the ZMQ lib to the path
    wide_command_string = std::wstring(L"addpath('") + path_to_matlab_zmq_lib + L"');" ;
    command_string = utf8_encode(wide_command_string) ;
    engEvalString(ep, command_string.c_str());

    //system("pause");

    // Create the satellite model object
    if ( looper_or_refiller == std::wstring(L"refiller") )
        {
        command_string = "refiller=ws.Refiller();" ;
        }
    else
        {
        command_string = "looper=ws.Looper();" ;
        }
    engEvalString(ep, command_string.c_str());  

    //system("pause");

    // Start the main loop of the model object
    if ( looper_or_refiller == std::wstring(L"refiller") )
        {
        command_string = "refiller.runMainLoop();" ;
        }
    else
        {
        command_string = "looper.runMainLoop();" ;
        }
    engEvalString(ep, command_string.c_str());  // this will block until the satellite exits

    //system("pause");

    // clear the model object (and all else) before closing the engine.  Otherwise we dump core (which is a problem).
    command_string = "clear;" ;
    engEvalString(ep, command_string.c_str());

    // close the engine
    engClose(ep);

    // wait for user
    std::cout << "About to exit normally from launch_satellite_engine.exe" << std::endl ;
    system("pause");
    //std::cout << "Press any key to exit..." << std::endl ;
    //kbhit() ;

    // exit    
    return(0);
    }

