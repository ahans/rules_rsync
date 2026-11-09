#include "rules_cc/cc/runfiles/runfiles.h"

#include <fstream>
#include <iostream>
#include <memory>
#include <string>

using rules_cc::cc::runfiles::Runfiles;

int main(int argc, char** argv) {
    std::string error;
    std::unique_ptr<Runfiles> runfiles{Runfiles::Create(argv[0], BAZEL_CURRENT_REPOSITORY, &error)};
    if (!runfiles) {
        std::cerr << "Runfiles init failed: " << error << "\n";
        return 1;
    }

    constexpr auto repo_path = "rules_rsync/test/hello.txt";
    std::string const path = runfiles->Rlocation(repo_path);
    if (path.empty()) {
        std::cerr << "Not found in runfiles\n";
        return 1;
    }

    std::cout << "Hello from C++!\n";
    std::ifstream in{path};
    std::cout << "test/hello.txt:\n";
    std::cout << in.rdbuf();

    return 0;
}
