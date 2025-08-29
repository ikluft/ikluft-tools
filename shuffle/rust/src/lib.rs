// shuffle_rs_ikluft: randomly shuffle lines of text from an input file (library)
// by Ian Kluft
// one of multiple programming language implementations of shuffle (C++, Go, Perl, Python and Rust)
// See https://github.com/ikluft/ikluft-tools/tree/master/shuffle
//
// Open Source licensing under terms of GNU General Public License version 3
// SPDX identifier: GPL-3.0-only
// https://opensource.org/licenses/GPL-3.0
// https://www.gnu.org/licenses/gpl-3.0.en.html

use anyhow::{bail, Context, Error, Result};
use rand::{seq::SliceRandom, thread_rng};
use std::{
    env,
    fs::File,
    io,
    io::{BufRead, BufReader},
    iter::Iterator,
    path::PathBuf,
};

// constants
const MAX_FILE_SIZE: u64 = 1 << 16; // 64K max - arbitrary but in-memory algorithm is only for small files

// get file path from command line
fn path_from_cli(mut args_iter: env::Args) -> Result<PathBuf, Error> {
    // skip command name in position 0 of command line argument list
    args_iter.next();

    // get input file name from command line
    let infile_param = args_iter.next().expect("file name parameter missing");
    let infile_path = PathBuf::from(infile_param);

    // basic file checks
    if ! infile_path.exists() {
        bail!("path does not exist: {}", infile_path.to_string_lossy());
    }
    if ! infile_path.is_file() {
        bail!("path is not a regular file: {}", infile_path.to_string_lossy());
    }
    let infile_metadata = infile_path.metadata()?;
    if infile_metadata.len() > MAX_FILE_SIZE {
        bail!("file is too large for in-memory shuffle algorithm: {}", infile_path.to_string_lossy());
    }

    // return path
    Ok(infile_path)
}

// read a file into a vector of strings
fn read_file_lines(infile_path: &PathBuf) -> Result<Vec<String>, Error> {
    let infile = File::open(infile_path).with_context(|| {
        format!(
            "Failed to open {}",
            infile_path.to_string_lossy()
        )
    })?;
    let reader = BufReader::new(infile);
    Ok(reader
        .lines()
        .filter_map(io::Result::ok)
        .collect::<Vec<String>>())
}

// run: library side of command line called from main()
pub fn run(args_iter: env::Args) -> Result<(), Error> {
    // get file path from command line
    let infile_path = path_from_cli(args_iter)?;

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

