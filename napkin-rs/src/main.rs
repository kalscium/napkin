use clap::Parser;
use napkin::{cli::Cli, tmp::read_tmp};

fn main() {
    // setup color-eyre
    color_eyre::install().unwrap();

    // parse the cli
    let cli = Cli::parse();

    // edit temporary file
    let text = read_tmp("I hate ...", "txt");
    println!("{text}");

    _ = cli;
}
