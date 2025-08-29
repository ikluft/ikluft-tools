// shuffle_rs_ikluft: randomly shuffle lines of text from an input file (CLI main)
// by Ian Kluft
// one of multiple programming language implementations of shuffle (C++, Go, Perl, Python and Rust)
// See https://github.com/ikluft/ikluft-tools/tree/master/shuffle
//
// Open Source licensing under terms of GNU General Public License version 3
// SPDX identifier: GPL-3.0-only
// https://opensource.org/licenses/GPL-3.0
// https://www.gnu.org/licenses/gpl-3.0.en.html
//
// usage: shuffle input.txt > output.txt

use anyhow::{Error, Result};
use std::env;

use shuffle_rs_ikluft::run;

// mainline - read file, shuffle it, output it
fn main() -> Result<(), Error> {
    // call run() with CLI arguments, returns run()'s Ok or Error from main
    run(env::args())
}
