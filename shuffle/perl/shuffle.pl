#!/usr/bin/env perl 
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
# usage: shuffle.pl input.txt > output.txt
use strict;
use warnings;
use utf8;
use List::Util qw(shuffle);

# shuffle the list
print shuffle (<>);
