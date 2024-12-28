#include <regex>

extern "C" {

struct RegexWrapper {
  std::regex regex;
};

RegexWrapper *createRegex(const char *pattern) {
  try {
    return new RegexWrapper{std::regex{pattern}};
  } catch (...) {
    return nullptr;
  }
}

void destroyRegex(RegexWrapper *regex) {
  delete regex;
  regex = nullptr;
}

bool matchRegex(const RegexWrapper *const regex, const char *str) {
  if (!regex)
    return false;
  try {
    return std::regex_match(str, regex->regex);
  } catch (...) {
    return false;
  }
}
}
