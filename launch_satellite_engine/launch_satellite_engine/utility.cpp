#include "utility.hpp"

// Convert a wide Unicode string to an UTF8 string
std::string utf8_encode(const std::wstring &wstr)
    {
    if( wstr.empty() ) return std::string();
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), NULL, 0, NULL, NULL);
    std::string strTo( size_needed, 0 );
    WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &strTo[0], size_needed, NULL, NULL);
    return strTo;
    }

// Convert an UTF8 string to a wide Unicode String
std::wstring utf8_decode(const std::string &str)
    {
    if( str.empty() ) return std::wstring();
    int size_needed = MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), NULL, 0);
    std::wstring wstrTo( size_needed, 0 );
    MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), &wstrTo[0], size_needed);
    return wstrTo;
    }

std::wstring GetEnvironmentVariableGracefully(std::wstring variable_name)
    {
    const wchar_t * raw_variable_name = variable_name.c_str() ;
    const unsigned long bufferSizeNeeded = GetEnvironmentVariable(raw_variable_name, (LPTSTR) 0, 0) ;
    wchar_t * wideCharBuffer = new wchar_t [bufferSizeNeeded] ;
    unsigned long nCharsInPath = GetEnvironmentVariable(raw_variable_name, wideCharBuffer, bufferSizeNeeded) ;
    if ( nCharsInPath == 0 )
        {
        delete [] wideCharBuffer ;
        throw std::runtime_error("unable to get environment variable") ;
        }
    std::wstring result = wideCharBuffer ;
    delete [] wideCharBuffer ;
    return result ;
    }

std::wstring extract_single_argument(const std::wstring & args, const size_t n)
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
        if ( args[i] == L'"')
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
        if ( args[i] == L'"')
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
    std::wstring result = args.substr(i_substring, substring_length) ;
    return result ;
    }

