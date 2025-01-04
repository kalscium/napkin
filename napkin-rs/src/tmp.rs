//! Functions for working with temporary text files

use core::panic;
use std::{fs, process::Command};

use color_eyre::eyre::Context;

/// Edits a file with the default editor
pub fn edit(path: &str) {
    // get the editor
    let editor = std::env::var("EDITOR")
        .wrap_err_with(|| "while getting $EDITOR environmental variable")
        .unwrap();

    // edit the file with the editor (command)
    let status = Command::new(&editor)
        .arg(path)
        .status()
        .wrap_err_with(|| format!("while editing file `{path}` with editor `{editor}`"))
        .unwrap();

    // check if it failed
    if !status.success() {
        panic!("non-zero termination signal from editor `{editor}` while editing file `{path}`");
    }
}

/// Creates a temporary file with an initial string and returns the edited result
pub fn read_tmp(initial: String) -> String {
    // generate a random number/id
    let random: usize = rand::random();

    // create tmp dir if it doesn't exist already
    let tmp_dir = crate::get_home().join("tmp");
    if !tmp_dir.is_dir() {
        fs::create_dir_all(&tmp_dir)
            .wrap_err_with(|| "while initialising napkin tmp dir")
            .unwrap();
    }

    // create a new file in the tmp dir with the initial text
    let file_path = tmp_dir.join(random.to_string());
    fs::write(&file_path, initial)
        .wrap_err_with(|| format!("while creating temporary file in {}", file_path.to_string_lossy()))
        .unwrap();


    // open and edit the file with the editor before saving the content
    edit(&file_path.to_string_lossy().to_string());
    let content = fs::read_to_string(&file_path)
        .wrap_err_with(|| format!("while reading the contents of file {}", file_path.to_string_lossy()))
        .unwrap();

    // clean up
    fs::remove_file(&file_path)
        .wrap_err_with(|| format!("while removing tmp file at path {}", file_path.to_string_lossy()))
        .unwrap();
    
    content
}
