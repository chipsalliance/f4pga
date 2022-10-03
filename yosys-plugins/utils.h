#include <algorithm>
#include <cctype>
#include <locale>

inline void trim_left(std::string &str)
{
    str.erase(str.begin(), std::find_if(str.begin(), str.end(), [](unsigned char ch) { return !std::isspace(ch); }));
}

inline void trim_right(std::string &str)
{
    str.erase(std::find_if(str.rbegin(), str.rend(), [](unsigned char ch) { return !std::isspace(ch); }).base(), str.end());
}

inline void trim(std::string &str)
{
    trim_left(str);
    trim_right(str);
}
