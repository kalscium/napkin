//! Functions for handling the locking of important files

use std::{fs, path::{Path, PathBuf}};

use color_eyre::eyre::Context;

/// A lock on an important file
#[derive(Debug)]
pub struct Lock {
    path: PathBuf,
}

/// Locks a the specified file by generating a lockfile of a similar name.
///
/// Returns an error if the lock is already present (some other process) is
/// locking the file.
pub fn lock(path: impl AsRef<Path>) -> Result<Lock, ()> {
    let path = path.as_ref();

    // derive the lockfile path
    let path = path.with_extension("lock");

    // check if it already exists (locked already)
    if path.exists() {
        return Err(());
    }

    // otherwise just lock and return the file
    fs::write(&path, [])
        .wrap_err_with(|| format!("while creating lock file '{}'", path.to_string_lossy()))
        .unwrap();

    Ok(Lock { path })
}

impl Drop for Lock {
    /// Locks the file on drop
    fn drop(&mut self) {
        // remove the lock file
        fs::remove_file(&self.path)
            .wrap_err_with(|| format!("while removing lock file '{}'", self.path.to_string_lossy()))
            .unwrap();
    }
}
