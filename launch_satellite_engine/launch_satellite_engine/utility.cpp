#include "utility.hpp"
#include "engine.h"
#include <vector>

// Convert a wide Unicode string to an UTF8 string
std::string narrow_from_wide(const std::wstring &wstr)
    {
    if( wstr.empty() ) return std::string();
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), NULL, 0, NULL, NULL);
    std::string strTo( size_needed, 0 );
    WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &strTo[0], size_needed, NULL, NULL);
    return strTo;
    }

// Convert an UTF8 string to a wide Unicode String
std::wstring wide_from_narrow(const std::string &str)
    {
    if( str.empty() ) return std::wstring();
    int size_needed = MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), NULL, 0);
    std::wstring wstrTo( size_needed, 0 );
    MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), &wstrTo[0], size_needed);
    return wstrTo;
    }

std::string GetEnvironmentVariableGracefully(std::string variable_name)
    {
    std::wstring wide_variable_name = wide_from_narrow(variable_name) ;
    const wchar_t * raw_wide_variable_name = wide_variable_name.c_str() ;
    const unsigned long bufferSizeNeeded = GetEnvironmentVariable(raw_wide_variable_name, (LPTSTR) 0, 0) ;
    wchar_t * wideCharBuffer = new wchar_t [bufferSizeNeeded] ;
    unsigned long nCharsInPath = GetEnvironmentVariable(raw_wide_variable_name, wideCharBuffer, bufferSizeNeeded) ;
    if ( nCharsInPath == 0 )
        {
        delete [] wideCharBuffer ;
        throw std::runtime_error("unable to get environment variable") ;
        }
    std::wstring wide_result = wideCharBuffer ;
    delete [] wideCharBuffer ;
    std::string result = narrow_from_wide(wide_result) ;
    return result ;
    }

std::string extract_single_argument(const std::string & args, const size_t n)
    {
    // Returns the (n+1)th argument
    // I.e. n is the zero-based index of the desired argument
    // Throws a std::domain_error if there aren't enough double quotes in args for the given n

    // Find the (2*n+1)'th double quote
    size_t n_quotes_to_skip = 2 * n ;
    size_t n_quotes_skipped = 0 ;
    size_t args_length = args.length() ;
    size_t i ;
    for (i=0; i<args_length; ++i)
        {
        if ( args[i] == '"')
            {
            if (n_quotes_skipped==n_quotes_to_skip)
                {
                break ;
                }
            else
                {
                n_quotes_skipped++ ;
                }
            }
        }

    if (i==args_length)
        {
        // failure
        // need to throw exception
        throw std::domain_error("not enough quotes in args");
        }
    
    size_t i_first_quote = i ;

    for (i=i_first_quote+1; i<args_length; i++)
        {
        if ( args[i] == '"')
            break ;
        }

    if (i==args_length)
        {
        // failure
        throw std::domain_error("not enough quotes in args");
        }
    
    size_t i_second_quote = i ;

    // If get here, i_first_quote is index of first quote, i_second_quote is index of second quote

    size_t i_substring = i_first_quote + 1 ;  // index (in args) of the first char in substring
    size_t substring_length = i_second_quote-i_substring ; 
    std::string result = args.substr(i_substring, substring_length) ;
    return result ;
    }

std::string string_from_mxArray(mxArray *matlab_string)
    {
    // Convert a row char array (i.e. a Matlab string) to a std::string

    // Determine the needed buffer size
    size_t string_length = mxGetN(matlab_string) ;
    size_t buffer_size = string_length + 1 ;

    // Create a buffer and size it appropriately
    std::vector<char> char_buffer ;
    char_buffer.resize(buffer_size) ;

    // Put the string into the buffer
    int retcode = mxGetString(matlab_string, &(char_buffer[0]), buffer_size);

    // Convert the buffer into a std::string
    std::string result ;
    if (retcode==0)
        {
        result = &(char_buffer[0]) ;
        }
    else
        {
        result = "" ;
        }

    return result ;
    }

