// shuffle lines of text from an input file
// by Ian Kluft

use rand::{seq::SliceRandom, thread_rng};
use std::{
    env,
    fs::File,
    io,
    io::{BufRead, BufReader},
    iter::Iterator,
    path::Path,
};

// read a file into a vector of strings
fn read_file_lines(infile_path: &Path) -> Vec<String> {
    let infile = match File::open(&infile_path) {
        Err(why) => panic!(
            "could not open input file {}: {}",
            infile_path.display(),
            why
        ),
        Ok(f) => f,
    };
    let reader = BufReader::new(infile);
    reader
        .lines()
        .filter_map(io::Result::ok)
        .collect::<Vec<String>>()
}

// mainline - read file, shuffle it, output it
fn main() -> io::Result<()> {
    // get input file name from command line
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        panic!("file name parameter missing");
    }
    let infile_path = Path::new(&args[1]);

    // read input file to vector
    let mut lines = read_file_lines(&infile_path);

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
