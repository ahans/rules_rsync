// Prints a data file found through the runfiles library.
#include <fstream>
#include <iostream>
#include <memory>
#include <string>

#include "rules_cc/cc/runfiles/runfiles.h"

using rules_cc::cc::runfiles::Runfiles;

int main(int argc, char** argv) {
  std::string error;
  std::unique_ptr<Runfiles> runfiles(Runfiles::Create(argv[0], BAZEL_CURRENT_REPOSITORY, &error));
  if (runfiles == nullptr) {
    std::cerr << error << std::endl;
    return 1;
  }
  std::ifstream in(runfiles->Rlocation("_main/tests/testdata/greeting.txt"));
  std::string line;
  std::getline(in, line);
  std::cout << "cc: " << line << std::endl;
  return in ? 0 : 1;
}
