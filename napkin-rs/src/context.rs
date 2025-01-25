//! Functions for dealing with the napkin context file

use std::{fs, path::{Path, PathBuf}};
use color_eyre::eyre::Context;
use crate::{configs, lock, tmp};

/// Initialises a new empty context file
pub fn init_context(path: impl AsRef<Path>) {
    let path = path.as_ref();

    let contents = format!("---\nversion: {}\nnapkins: [ ]\n...", env!("CARGO_PKG_VERSION"));

    fs::write(path, contents)
        .wrap_err_with(|| format!("while initialising napkin context file at {}", path.to_string_lossy()))
        .unwrap();
}

/// Gets the path to the context file
#[inline]
pub fn context_path() -> PathBuf {
    crate::get_home().join("context.yml")
}

/// Opens and edits the context file
pub fn open_context() {
    let path = context_path();

    // lock the context file before any modifications
    let _ = lock::lock(&path)
        .expect("there is currently a lock on the napkin context file! run `napkin clean` to clear it if you believe this is a mistake.");

    // check if the context file exists or not, if not, then init one
    if !path.exists() {
        init_context(&path);
    }

    // read the contents of the file
    let contents = fs::read_to_string(&path)
        .wrap_err_with(|| "while reading from the napking context file")
        .unwrap();

    // read the temporary edits to the file as a string and then parse them
    let mut input = tmp::read_tmp(&contents, "yml");
    let yaml = loop {
        match configs::parse_yaml(&input) {
            Ok(yaml) => break yaml,
            Err(err) => input = tmp::read_tmp(
                &configs::yaml_annotate(&input, err), "yml"
            ),
        }
    };
}
