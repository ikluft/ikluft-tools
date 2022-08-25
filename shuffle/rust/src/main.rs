// shuffle: randomly shuffle lines of text from an input file
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

use anyhow::{anyhow, Context, Result};
use rand::{seq::SliceRandom, thread_rng};
use std::{
    env::args,
    fs::File,
    io,
    io::{BufRead, BufReader},
    iter::Iterator,
    path::Path,
};

// read a file into a vector of strings
fn read_file_lines(infile_path: &Path) -> Result<Vec<String>, anyhow::Error> {
    let infile = File::open(&infile_path)
        .with_context(|| format!("Failed to read instrs from {}", infile_path.to_string_lossy()))?;
    let reader = BufReader::new(infile);
    Ok(reader
        .lines()
        .filter_map(io::Result::ok)
        .collect::<Vec<String>>())
}

// mainline - read file, shuffle it, output it
fn main() -> Result<()> {
    // get input file name from command line
    let args: Vec<String> = args().collect();
    if args.len() < 2 {
        return Err(anyhow!("file name parameter missing"));
    }
    let infile_path = Path::new(&args[1]);

    // read input file to vector
    let mut lines = read_file_lines(&infile_path)?;

    // shuffle vector
    let mut rng = thread_rng();
    lines.shuffle(&mut rng);

    // print vector
    for line in lines {
        println!("{}", line);
    }

    // done
    Ok(())
}
