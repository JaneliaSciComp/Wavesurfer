#ifndef UTILITY_HPP
#define UTILITY_HPP

#include <string>
#include <windows.h>
#include "engine.h"

std::string narrow_from_wide(const std::wstring &wstr) ;
std::wstring wide_from_narrow(const std::string &str) ;
std::string GetEnvironmentVariableGracefully(std::string variable_name) ;
std::string extract_single_argument(const std::string & args, const size_t n) ;
std::string string_from_mxArray(mxArray *matlab_string) ;

#endif