use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(author, version, about)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Command,
}

#[derive(Subcommand)]
pub enum Command {
    #[command(about="Lists all the napkins currently stored & managed prettily")]
    List,
    #[command(about="Removes files from the napkin home that aren't referenced")]
    Clean,
    #[command(about="Opens and edits the context file")]
    Context,
    #[command(about="Creates a new napkin in the napkin home")]
    New,
    #[command(about="Edits the meta-data of a pre-existing napkin")]
    Meta {
        #[arg(index=1, help="The uid of the napkin in question")]
        uid: u128,
    },
    #[command(about="Edits the the contents of a pre-existing napkin")]
    Edit {
        #[arg(index=1, help="The uid of the napkin in question")]
        uid: u128,
    },
    #[command(about="Exports the napkins of the specified uids in a tarball (all if none specified)")]
    Export {
        #[arg(short, long, num_args=.., help="The uids of the napkins to export (all if none specified)")]
        uids: Vec<u128>,
        #[arg(short='o', long="output", help="The output path of the tarball")]
        path: String,
    },
    Import {
        #[arg(index=1, help="The path of the tarball to import")]
        path: String,
        #[arg(short='b', long, help="Whether to favor the tarball backup (if true) or the napkin-home (default)")]
        favor_backup: bool,
    },
}
