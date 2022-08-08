#!/usr/bin/env python3
"""randomly shuffle lines of text from input file"""
# shuffle: randomly shuffle lines of text from an input file
# by Ian Kluft
# one of multiple programming language implementations of shuffle (C++, Go, Perl, Python and Rust)
# See https://github.com/ikluft/ikluft-tools/tree/master/shuffle
#
# Open Source licensing under terms of GNU General Public License version 3
# SPDX identifier: GPL-3.0-only
# https://opensource.org/licenses/GPL-3.0
# https://www.gnu.org/licenses/gpl-3.0.en.html
#
# usage: shuffle.py infile > outfile
import sys
import random

# read list from file
file = sys.argv[1]
with open(file, 'r') as infile:
    words = infile.readlines()

# shuffle list and output
random.shuffle(words)
sys.stdout.writelines(words)
