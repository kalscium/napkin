use clap::Parser;
use napkin::{cli::Cli, configs, tmp::read_tmp};

fn main() {
    // setup color-eyre
    color_eyre::install().unwrap();

    // parse the cli
    let cli = Cli::parse();

    // edit temporary file
    let mut text = read_tmp("# write some yaml here", "yml");
    println!("{text}");

    // error testing
    loop {
        let yaml = match configs::parse_yaml(&text) {
            Ok(yaml) => yaml,
            Err(err) => {
                let annotated = configs::yaml_annotate(&text, err);
                text = read_tmp(&annotated, "yml");

                continue;
            },
        };

        if let Err(err) = configs::yaml_get_list("example-list", &yaml) {
            let annotated = configs::yaml_annotate(&text, err);
            text = read_tmp(&annotated, "yml");
            continue;
        }

        if let Err(err) = configs::yaml_get_date("example-date", &yaml) {
            let annotated = configs::yaml_annotate(&text, err);
            text = read_tmp(&annotated, "yml");
            continue;
        } else {
            break;
        }
    };

    _ = cli;
}
