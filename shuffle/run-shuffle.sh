#!/bin/sh
# run-shuffle.sh - run the various language implementations of shuffle and create a key of which
# implementations made which output files
#
# by Ian Kluft
# runs each of multiple programming language implementations of shuffle (C++, Go, Perl, Python and Rust)
# See https://github.com/ikluft/ikluft-tools/tree/master/shuffle
#
# Open Source licensing under terms of GNU General Public License version 3
# SPDX identifier: GPL-3.0-only
# https://opensource.org/licenses/GPL-3.0
# https://www.gnu.org/licenses/gpl-3.0.en.html
#
# dependencies:
#   general: date dirname expr printf realpath shuf test (all part of GNU coreutils)
#   C++: Gnu C++ compiler, Gnu Make
#   Go: Go compiler
#   Perl: Perl interpreter
#   Python: Python interpreter
#   Rust: Rust compiler, cargo

# obtain the directory where run-shuffle.sh resides because language implementations are under it
dir="$(dirname "$(realpath "$0")")"

# read command-line parameters
if [ $# -lt 2 ]
then
    echo "usage: $0 prefix input-file" >&2
    echo "   prefix: string to use as prefix on output files" >&2
    echo "   input-file: path to text file with lines intended to be shuffled" >&2
    exit 1
fi

# initialize
prefix="$1"
input="$2"
count=0
langs="c cpp go perl python rust"
timestamp=$(date '+%Y-%m-%d-%H-%M-%S')
keyfile="$prefix-$timestamp-key.txt"

# check condition of input file: must exist and be a file
if [ ! -e "$input" ]
then
    echo "input file path points to non-existent entry: $input" >&2
    exit 1
fi
if [ ! -f "$input" ]
then
    echo "input file path points to non-file: $input" >&2
    exit 1
fi
if [ ! -r "$input" ]
then
    echo "input file path points to unreadable file: $input" >&2
    exit 1
fi

# 
# functions to run each language implementation
#

# C implemented by shuf(1) from GNU coreutils
run_c()
{
    echo "run C"
    infile="$1"
    outfile="$2"
    shuf "$infile" > "$outfile"
    printf "%03d %6s %s\n" $count "C" "$outfile" >> "$keyfile"
}

# C++ implemented by shuffle suite
run_cpp()
{
    echo "run C++"
    infile="$1"
    outfile="$2"
    if ( cd "$dir/cpp" && make )
    then
        "$dir/cpp/shuffle" "$infile" > "$outfile"
        printf "%03d %6s %s\n" $count "C++" "$outfile" >> "$keyfile"
    fi
}

# Go implemented by shuffle suite
run_go()
{
    echo "run Go"
    infile="$1"
    outfile="$2"
    if ( cd "$dir/go" && go build shuffle.go )
    then
        "$dir/go/shuffle" "$infile" > "$outfile"
        printf "%03d %6s %s\n" $count "Go" "$outfile" >> "$keyfile"
    fi
}

# Perl implemented by shuffle suite
run_perl()
{
    echo "run Perl"
    infile="$1"
    outfile="$2"
    "$dir/perl/shuffle.pl" "$infile" > "$outfile"
    printf "%03d %6s %s\n" $count "Perl" "$outfile" >> "$keyfile"
}

# Python implemented by shuffle suite
run_python()
{
    echo "run Python"
    infile="$1"
    outfile="$2"
    "$dir/python/shuffle.py" "$infile" > "$outfile"
    printf "%03d %6s %s\n" $count "Python" "$outfile" >> "$keyfile"
}

# Rust implemented by shuffle suite
run_rust()
{
    echo "run Rust"
    infile="$1"
    outfile="$2"
    if ( cd "$dir/rust" && cargo build )
    then
        "$dir/rust/target/debug/shuffle" "$infile" > "$outfile"
        printf "%03d %6s %s\n" $count "Rust" "$outfile" >> "$keyfile"
    fi
}

#
# main 
#
# shellcheck disable=SC2086 # disable "Double quote to prevent globbing" warning since we want globbing here
for lang in $(shuf --echo $langs)
do
    if [ "$lang" = "c" ] || [ -d "$dir/$lang" ]
    then
        "run_$lang" "$input" "$(printf "%s-%s-%03d.txt" "$prefix" "$timestamp" $count)"
    fi
    count=$((count + 1))
done
