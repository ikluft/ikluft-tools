// pathmunge: add to Unix PATH with deduplication
// by Ian Kluft
// usage: pathmunge [--before dir:dir:dir] [--after dir:dir:dir] [--var=varname]

use anyhow::Result;
use clap::{Arg, ArgGroup, Command};
use std::{
    collections::HashSet,
    env,
    path::Path,
    string::{String, ToString},
    vec::Vec,
};

// constants
const DEFAULT_VAR_NAME: &str = "PATH";
const DEFAULT_DELIMETER: &str = ":";

// add to Unix PATH or similar environment variable with deduplication
fn main() -> Result<()> {
    // command-line interface
    let cli = Command::new("pathmunge")
        .about("add to a Unix PATH or similar environment variable with deduplication")
        .arg(
            Arg::new("before")
                .long("before")
                .value_name("PATH")
                .num_args(1),
        )
        .arg(
            Arg::new("after")
                .long("after")
                .value_name("PATH")
                .num_args(1),
        )
        .group(
            ArgGroup::new("position")
                .args(["before", "after"])
                .multiple(true)
                .required(true),
        )
        .arg(
            Arg::new("var")
                .long("var")
                .num_args(1)
                .required(false)
                .value_name("VARNAME")
                .default_value(DEFAULT_VAR_NAME),
        );

    // check for errors
    let result = cli.try_get_matches();
    let matches = result?; // unwrap matches from result or end with CLI error

    // extract values
    let before = matches.get_one::<String>("before");
    let after = matches.get_one::<String>("after");
    let var_name = matches.get_one::<String>("var");

    // read the specified environment variable (default PATH), if it exists
    let env_value = env::var(var_name.unwrap_or(&DEFAULT_VAR_NAME.to_string()));

    // assemble path element strings
    let mut elements: Vec<String> = Vec::new();
    // before.unwrap_or("".to_string()).split(":").collect();
    if before.is_some() {
        elements.push(before.unwrap().to_string());
    }
    if env_value.is_ok() {
        elements.push(env_value.unwrap().to_string());
    }
    if after.is_some() {
        elements.push(after.unwrap().to_string());
    }

    // assemble path directories into ordered set, skipping duplicates and invalid paths
    let mut path_out: Vec<String> = Vec::new();
    let mut dirs_seen: HashSet<String> = HashSet::new();
    for element in elements.iter() {
        // split element into directory strings
        let dir_strs: Vec<&str> = element.split(DEFAULT_DELIMETER).collect();
        for dir_str in dir_strs.into_iter() {
            // skip entries already in dirs_seen set
            if dirs_seen.contains(dir_str) {
                continue;
            }

            // convert directory string into a path and check validity
            let dir_path = Path::new(dir_str);
            if !dir_path.exists() {
                // skip paths that don't exist
                continue;
            }
            if !dir_path.is_dir() {
                // skip paths that aren't directories
                continue;
            }

            // add dir to path and mark as seen
            dirs_seen.insert(dir_str.to_string());
            path_out.push(dir_str.to_string());
        }
    }

    // join path with separator and print it
    let path_str: String = path_out.join(DEFAULT_DELIMETER);
    println!("{}", path_str);

    // done
    Ok(())
}
