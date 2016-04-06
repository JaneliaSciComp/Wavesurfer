#ifndef UTILITY_HPP
#define UTILITY_HPP

#include <string>
#include <windows.h>
#include "engine.h"

std::string utf8_encode(const std::wstring &wstr) ;
std::wstring utf8_decode(const std::string &str) ;
std::wstring GetEnvironmentVariableGracefully(std::wstring variable_name) ;
std::wstring extract_single_argument(const std::wstring & args, const size_t n) ;
std::string string_from_mxArray(mxArray *matlab_string) ;

#endif