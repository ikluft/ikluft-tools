// pathfilter: add to Unix PATH with deduplication
// by Ian Kluft
// usage: pathfilter [--before dir:dir:dir] [--after dir:dir:dir] [--var=varname]

use anyhow::Result;
use clap::{Arg, ArgGroup, Command};
use std::{
    collections::HashSet,
    env,
    path::Path,
    process,
    string::{String, ToString},
    vec::Vec,
};

// constants
const DEFAULT_VAR_NAME: &str = "PATH";
const DEFAULT_DELIMITER: &str = ":";
const BEFORE_PARAM: &str = "before";
const AFTER_PARAM: &str = "after";
const VAR_PARAM: &str = "var";
const DELIMITER_PARAM: &str = "delimiter";

// command line data
struct CliOpts {
    before: Option<String>,
    after: Option<String>,
    var_name: String,
    delimiter: String,
}

// process command line and return values
fn process_cli() -> Result<CliOpts, anyhow::Error> {
    // command-line interface
    let result = Command::new("pathfilter")
        .about("Pathfilter adds to a Unix PATH or similar environment variable with deduplication of path elements")
        .arg(
            Arg::new(BEFORE_PARAM)
                .long(BEFORE_PARAM)
                .value_name("PATH")
                .num_args(1),
        )
        .arg(
            Arg::new(AFTER_PARAM)
                .long(AFTER_PARAM)
                .value_name("PATH")
                .num_args(1),
        )
        .group(
            ArgGroup::new("position")
                .args([BEFORE_PARAM, AFTER_PARAM])
                .multiple(true)
                .required(true),
        )
        .arg(
            Arg::new(VAR_PARAM)
                .long(VAR_PARAM)
                .num_args(1)
                .required(false)
                .value_name("VARNAME")
                .default_value(DEFAULT_VAR_NAME),
        )
        .arg(
            Arg::new(DELIMITER_PARAM)
                .long(DELIMITER_PARAM)
                .num_args(1)
                .required(false)
                .value_name("DELIMITER")
                .default_value(DEFAULT_DELIMITER),
        );

    // check for errors
    let result = result.try_get_matches();
    let matches = result?; // unwrap matches from result or return with CLI error

    // extract values
    let cli = CliOpts {
        // extract CLI params as Options since these may be missing
        before: matches.get_one::<String>(BEFORE_PARAM).cloned(),
        after: matches.get_one::<String>(AFTER_PARAM).cloned(),

        // extract and unwrap CLI params which won't be empty due to a default value
        var_name: matches.get_one::<String>(VAR_PARAM).unwrap().to_owned(),
        delimiter: matches
            .get_one::<String>(DELIMITER_PARAM)
            .unwrap()
            .to_owned(),
    };

    Ok(cli)
}

// assemble elements of path from CLI option and environment
fn assemble_elements(cli: &CliOpts) -> Vec<String> {
    // read the specified environment variable (default PATH), if it exists
    let env_value = env::var(&cli.var_name);

    // assemble path element strings
    let mut elements: Vec<String> = Vec::new();
    if cli.before.is_some() {
        let before = cli.before.to_owned().unwrap();
        elements.push(before);
    }
    if env_value.is_ok() {
        elements.push(env_value.unwrap());
    }
    if cli.after.is_some() {
        let after = cli.after.to_owned().unwrap();
        elements.push(after);
    }

    // return the vector of path elements
    elements
}

// assemble path directories into ordered set, skipping duplicates and invalid paths
fn gen_path(cli: CliOpts, elements: Vec<String>) -> String {
    // assemble path directories into ordered set, skipping duplicates and invalid paths
    let mut path_out: Vec<String> = Vec::new();
    let mut dirs_seen: HashSet<String> = HashSet::new();
    for element in &elements {
        // split element into directory strings
        let dir_strs: Vec<&str> = element.split(cli.delimiter.as_str()).collect();
        for dir_str in &dir_strs {
            // canonicalize and convert to OsStr for checking if it's unique
            let dir_path = Path::new(dir_str);
            let dir_canonical = match dir_path.canonicalize() {
                Ok(x) => x.to_string_lossy().to_string(),
                Err(_) => continue,
            };

            // skip entries already in dirs_seen set
            if dirs_seen.contains(&dir_canonical) {
                continue;
            }

            // convert directory string into a path and check validity
            if !dir_path.exists() {
                // skip paths that don't exist
                continue;
            }
            if !dir_path.is_dir() {
                // skip paths that aren't directories
                continue;
            }

            // add dir to path and mark as seen
            path_out.push(dir_canonical.to_string());
            dirs_seen.insert(dir_canonical);
        }
    }

    // join path with separator and return it
    path_out.join(cli.delimiter.as_str())
}

// add to Unix PATH or similar environment variable with deduplication
fn main() {
    // get command-line data
    let cli = match process_cli() {
        Ok(x) => x,
        Err(e) => {
            eprintln!("{e}");
            process::exit(1);
        }
    };

    // assemble elements of path from CLI option and environment
    let elements = assemble_elements(&cli);

    // get path and print it
    let path_str = gen_path(cli, elements);
    println!("{}", path_str);
}
