/*
 * shuffle: randomly shuffle lines of text from an input file
 * by Ian Kluft
 * one of multiple programming language implementations of shuffle (C++, Go, Perl, Python and Rust)
 * See https://github.com/ikluft/ikluft-tools/tree/master/shuffle
 *
 * Open Source licensing under terms of GNU General Public License version 3
 * SPDX identifier: GPL-3.0-only
 * https://opensource.org/licenses/GPL-3.0
 * https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * usage: shuffle input.txt > output.txt
 */

// library headers
#include <iostream>
#include <fstream>
#include <cstdlib>
#include <string>
#include <vector>
#include <random>
#include <algorithm>

/*
 * main - read file, shuffle it, output it
 */
int main(const int argc, const char **argv)
{
    // make sure we have enough arguments to find file name
    if (argc < 1) {
        std::cerr << "usage: " << argv[0] << " infile" << std::endl;
        std::exit(1);
    }

    // read input file to vector
    std::vector<std::string> lines;
    {
        // open the input file
        std::ifstream infile(argv[1]);
        if (!infile.is_open()) {
            std::cerr << "failed to open input file " << argv[1] << std::endl;
            std::exit(1);
        }

        // read the input file
        std::string line;
        while (getline(infile, line)) {
            lines.emplace_back(line);
        }
    }

    // shuffle the vector
    std::random_device rd;
    std::minstd_rand generator(rd()); // algorithm is random enough, fast enough, minimal memory
    std::shuffle(lines.begin(), lines.end(), generator);

    // print the sorted vector
    for (auto item: lines) {
        std::cout << item << std::endl;
    }

    return 0;
}
