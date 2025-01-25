pub mod cli;
pub mod tmp;
pub mod configs;
pub mod lock;
pub mod context;

pub fn get_home() -> std::path::PathBuf {
    use color_eyre::eyre::ContextCompat;
    home::home_dir()
        .wrap_err_with(|| "while getting the home directory")
        .unwrap()
        .join(".napkin")
}
