#include <regex>
#include <string>

extern "C" {

struct RegexWrapper {
  std::regex regex;
};

RegexWrapper *createRegex(const char *pattern, unsigned long count) {
  try {
    return new RegexWrapper{std::regex{std::string{pattern, count}}};
  } catch (...) {
    return nullptr;
  }
}

void destroyRegex(RegexWrapper *regex) {
  delete regex;
  regex = nullptr;
}

bool matchRegex(const RegexWrapper *const regex, const char *str,
                unsigned long int count) {
  if (!regex)
    return false;
  try {
    return std::regex_search(std::string{str, count}, regex->regex);
  } catch (...) {
    return false;
  }
}
}
