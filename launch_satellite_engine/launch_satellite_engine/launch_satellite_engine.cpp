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
    // To show the .exe was called properly
    OutputDebugString(L"Inside launch_satellite_engine.exe\n");

    // Get the command-line arguments into something civilized
    std::wstring args = lpszCmdLine ;

    // Read the debug arg
    std::wstring release_or_debug ;
    try
        {
        release_or_debug    = extract_single_argument(args, 0) ;
        }
    catch (std::domain_error)
        {
        release_or_debug = L"debug" ;
        }

    bool is_debug = (release_or_debug != std::wstring(L"release")) ;

    if (is_debug)
        {
        // Create a console for stdin/stdout
        AllocConsole();

        // Set things up so stdout/stdin go to the console
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

        // Output something to show that worked
        std::cout << "Debug mode enabled" << std::endl ;
        }

    // Process the rest of the command-line args
    std::wstring looper_or_refiller, matlab_bin_path, path_to_repo_root, path_to_matlab_zmq_lib;
    try
        {
        looper_or_refiller      = extract_single_argument(args, 1) ;
        }
    catch (std::domain_error)
        {
        exit(-1) ;
        }
    std::wcout << L"looper_or_refiller: " << looper_or_refiller << std::endl ;

    try
        {
        matlab_bin_path         = extract_single_argument(args, 2) ;
        }
    catch (std::domain_error)
        {
        exit(-2) ;
        }
    std::wcout << L"matlab_bin_path: " << matlab_bin_path << std::endl ;

    try
        {
        path_to_repo_root       = extract_single_argument(args, 3) ;
        }
    catch (std::domain_error)
        {
        exit(-3) ;
        }
    std::wcout << L"path_to_repo_root: " << path_to_repo_root << std::endl ;

    try
        {
        path_to_matlab_zmq_lib  = extract_single_argument(args, 4) ;
        }
    catch (std::domain_error)
        {
        exit(-4) ;
        }
    std::wcout << L"path_to_matlab_zmq_lib: " << path_to_matlab_zmq_lib << std::endl ;

    // Get the current path
    std::wstring original_path ;
    try
        {
        original_path = GetEnvironmentVariableGracefully(std::wstring(L"Path")) ;
        }
    catch ( std::runtime_error )
        {
        // If running in release mode, this will do nothing
        std::wcout << L"Unable to read path environment variable.  Exiting." << std::endl ;
        //MessageBox((HWND)NULL, (LPCWSTR) L"Unable to read Path environment variable", 
        //           (LPCWSTR) L"Boo", MB_OK) ;
        exit(-5) ;
        }
    std::wcout << L"original_path: " << original_path << std::endl ;

    // Construct the new path
    std::wstring new_path = matlab_bin_path + L";" + original_path ;

    // Set the env var to the new path
    int didSucceed = SetEnvironmentVariable(L"Path", new_path.c_str()) ;
    if (!didSucceed)
        {
        std::wcout << L"Unable to set path environment variable.  Exiting." << std::endl ;
        exit(-6) ;
        }
    std::wcout << L"new_path (we think/hope): " << new_path << std::endl ;

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
    std::cout << "About to start the Matlab engine..." << std::endl ;
    //Engine * ep = engOpen(NULL) ;
    int retcode ;
    Engine * ep = engOpenSingleUse(NULL, NULL, &retcode) ;
    if ( !ep ) 
        {
        //MessageBox((HWND)NULL, (LPCWSTR) L"Can't start MATLAB engine", 
        //           (LPCWSTR) L"Boo", MB_OK);
        std::wcout << L"Unable to start Matlab engine.  Exiting." << std::endl ;
        exit(-7);
        }
    std::cout << "Just started Matlab engine successfully." << std::endl ;
    std::cout << "ep: " << ep <<std::endl ;

    // Make the command window invisible
    engSetVisible(ep, is_debug);

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
    std::wcout << L"About to start the " << looper_or_refiller << L" main loop..." << std::endl ;
    if ( looper_or_refiller == std::wstring(L"refiller") )
        {
        command_string = "refiller.runMainLoop();" ;
        }
    else
        {
        command_string = "looper.runMainLoop();" ;
        }
    engEvalString(ep, command_string.c_str());  // this will block until the satellite exits
    std::wcout << L"The " << looper_or_refiller << L" main loop exited." << std::endl ;

    //std::cout << "Normally we'd be running the main loop now..." << std::endl ;
    //system("pause");

    // Check for errors in the engine
    command_string = "err = MException.last()" ;
    int err = engEvalString(ep, command_string.c_str()) ;
    if (!err)
        {
        mxArray *engine_error = engGetVariable(ep, "err") ; 
        if (engine_error)
            {
            mxArray *engine_error_message_mxArray = mxGetProperty(engine_error, 0, "message") ;
            if (engine_error_message_mxArray)
                {
                std::string engine_error_message = string_from_mxArray(engine_error_message_mxArray) ;
                if ( engine_error_message.length() != 0 )
                    {
                    std::cout << "There was at least one error in the engine: " << engine_error_message << std::endl ;
                    }

                // clear the model object (and all else) before closing the engine.  Otherwise we dump core (which is a problem).
                command_string = "clear;" ;
                engEvalString(ep, command_string.c_str());
                }
            else
                {
                std::cout << "When we went to check for errors, the engine_error_message_mxArray pointer was null" << std::endl ;
                }
            }
        else
            {
            std::cout << "When we went to check for errors, the engine_error pointer was null" << std::endl ;
            }
        }
    else
        {
        std::cout << "When we went to check for errors, we found the Matlab engine is no longer running." << std::endl ;
        }

    // close the engine
    engClose(ep);

    // wait for user
    std::cout << "About to exit normally from launch_satellite_engine.exe" << std::endl ;
    if (is_debug)
        {
        std::cout << std::endl ;
        system("pause");
        }
    //std::cout << "Press any key to exit..." << std::endl ;
    //kbhit() ;

    // exit    
    return(0);
    }

