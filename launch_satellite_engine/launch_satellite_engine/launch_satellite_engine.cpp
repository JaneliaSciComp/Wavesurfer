#include <windows.h>
#include <stdio.h>
#include <io.h>
#include <fcntl.h>
#include <string>
#include "engine.h"
#include <iostream>
#include "utility.hpp"

int WINAPI WinMain (HINSTANCE hInstance,
                    HINSTANCE hPrevInstance,
                    LPSTR     lpCmdLine,
                    int       nCmdShow)
    {
    // To show the .exe was called properly
    OutputDebugString(L"Inside launch_satellite_engine.exe\n");

    // Get the command-line arguments into something civilized
    std::string args = lpCmdLine ;

    // Read the debug arg
    std::string release_or_debug ;
    try
        {
        release_or_debug    = extract_single_argument(args, 0) ;
        }
    catch (std::domain_error)
        {
        release_or_debug = "debug" ;
        }

    bool is_debug = (release_or_debug != std::string("release")) ;

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
    std::string looper_or_refiller, path_to_ws_root, path_to_matlab_zmq_lib;
    try
        {
        looper_or_refiller      = extract_single_argument(args, 1) ;
        }
    catch (std::domain_error)
        {
        exit(-1) ;
        }
    std::cout << "looper_or_refiller: " << looper_or_refiller << std::endl ;

    // Matlab automatically adds dir to the path for things called via system() matlab function
    /*
    try
        {
        matlab_bin_path         = extract_single_argument(args, 2) ;
        }
    catch (std::domain_error)
        {
        exit(-2) ;
        }
    std::cout << "matlab_bin_path: " << matlab_bin_path << std::endl ;
    */

    try
        {
        path_to_ws_root       = extract_single_argument(args, 2) ;
        }
    catch (std::domain_error)
        {
        exit(-2) ;
        }
    std::cout << "path_to_ws_root: " << path_to_ws_root << std::endl ;

    try
        {
        path_to_matlab_zmq_lib  = extract_single_argument(args, 3) ;
        }
    catch (std::domain_error)
        {
        exit(-3) ;
        }
    std::cout << "path_to_matlab_zmq_lib: " << path_to_matlab_zmq_lib << std::endl ;

    /*
    // Get the current path
    std::string original_path ;
    try
        {
        original_path = GetEnvironmentVariableGracefully(std::string("Path")) ;
        }
    catch ( std::runtime_error )
        {
        // If running in release mode, this will do nothing
        std::cout << "Unable to read path environment variable.  Exiting." << std::endl ;
        //MessageBox((HWND)NULL, (LPCWSTR) L"Unable to read Path environment variable", 
        //           (LPCWSTR) L"Boo", MB_OK) ;
        exit(-5) ;
        }
    std::cout << "original_path: " << original_path << std::endl ;

    // Construct the new path
    std::string new_path = matlab_bin_path + ";" + original_path ;

    // Set the env var to the new path
    std::wstring wide_new_path = wide_from_narrow(new_path) ;
    int didSucceed = SetEnvironmentVariable(L"Path", wide_new_path.c_str()) ;
    if (!didSucceed)
        {
        std::cout << "Unable to set path environment variable.  Exiting." << std::endl ;
        exit(-6) ;
        }
    std::cout << "new_path (we think/hope): " << new_path << std::endl ;

    //// Get the path again, to check it
    //std::string new_path_check ;
    //try
    //    {
    //    new_path_check = GetEnvironmentVariableGracefully(std::string(L"Path")) ;
    //    }
    //catch ( std::runtime_error )
    //    {
    //    MessageBox((HWND)NULL, (LPCWSTR) L"Unable to read Path environment variable to check it", 
    //               (LPCWSTR) L"Boo", MB_OK) ;
    //    exit(-1) ;
    //    }

    //// Show the new path
    //MessageBox((HWND)NULL, (LPCWSTR) new_path_check.c_str(), 
    //           (LPCWSTR) L"Path, after", MB_OK) ;
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
        std::cout << L"Unable to start Matlab engine.  Exiting." << std::endl ;
        exit(-7);
        }
    std::cout << "Just started Matlab engine successfully." << std::endl ;
    std::cout << "ep: " << ep <<std::endl ;

    // Make the command window invisible
    engSetVisible(ep, is_debug);

    // Execute the commands that will start the satellite main loop
    //"addpath(''%s''); addpath(''%s''); looper=ws.Looper(); looper.runMainLoop(); clear; quit()"
    std::string wide_command_string ;
    std::string command_string ;

    //system("pause");

    // Print out which satellite this is, because this is sometimes good to know, esp. when debugging
    //command_string = std::string("fprintf('This is the ") + looper_or_refiller + " process.\\n\\n');" ;
    // This doesn't work, b/c Matlab Engine doesn't output the (textual) results of commands executed with
    // engEvalString() to the matlab command window.  This is by design, apparently.
    /*
    command_string = std::string("ver") ;
    engEvalString(ep, command_string.c_str());
    command_string = std::string("pause(0.01)") ;
    engEvalString(ep, command_string.c_str());
    */

    // Add the WS root to the path
    command_string = std::string("addpath('") + path_to_ws_root + "');" ;
    engEvalString(ep, command_string.c_str());

    //system("pause");

    // Add the ZMQ lib to the path
    command_string = std::string("addpath('") + path_to_matlab_zmq_lib + "');" ;
    engEvalString(ep, command_string.c_str());

    //system("pause");

    // Create the satellite model object
    if ( looper_or_refiller == std::string("refiller") )
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
    std::cout << "About to start the " << looper_or_refiller << " main loop..." << std::endl ;
    if ( looper_or_refiller == std::string("refiller") )
        {
        command_string = "refiller.runMainLoop();" ;
        }
    else
        {
        command_string = "looper.runMainLoop();" ;
        }
    engEvalString(ep, command_string.c_str());  // this will block until the satellite exits
    std::cout << "The " << looper_or_refiller << " main loop exited." << std::endl ;

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
