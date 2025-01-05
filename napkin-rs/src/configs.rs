//! Functions for dealing with napkin yaml config files

use chrono::{DateTime, FixedOffset};
use yaml_rust2::{ScanError, Yaml, YamlLoader};

/// Errors that may occur while parsing the yaml
#[derive(Debug, Clone)]
pub enum Error {
    InvalidYaml(ScanError),
    MissingKey(String),
    WrongKeyType {
        key: String,
        expected_type: &'static str,
    },
    EmptyYaml,
    NonHashMapDoc,
    MultipleYamlDocs,
    InvalidDate(String),
}

/// Parses a yaml string while converting any errors that occur
pub fn parse_yaml(yaml: &str) -> Result<Yaml, Error> {
    let yaml = YamlLoader::load_from_str(yaml)
        .map_err(|err| Error::InvalidYaml(err))?;
    
    // check yaml doc's length
    if yaml.len() > 1 {
        return Err(Error::MultipleYamlDocs);
    }
    if yaml.is_empty() {
        return Err(Error::EmptyYaml);
    }

    // make sure it's a hashmap
    if !yaml[0].is_hash() {
        return Err(Error::NonHashMapDoc);
    }

    Ok(yaml[0].clone()) // ignores additional documents
}

/// Accesses a value from the yaml document, while wrapping errors
pub fn yaml_get_str(key: &str, yaml: &Yaml) -> Result<String, Error> {
    match yaml[key] {
        Yaml::String(ref string) => Ok(string.clone()),
        Yaml::BadValue => Err(Error::MissingKey(key.to_string())),

        _ => Err(Error::WrongKeyType {
            key: key.to_string(),
            expected_type: "string",
        }),
    }
}

/// Accesses a value from the yaml document, while wrapping errors
pub fn yaml_get_bool(key: &str, yaml: &Yaml) -> Result<bool, Error> {
    match yaml[key] {
        Yaml::Boolean(bool) => Ok(bool),
        Yaml::BadValue => Err(Error::MissingKey(key.to_string())),

        _ => Err(Error::WrongKeyType {
            key: key.to_string(),
            expected_type: "boolean",
        }),
    }
}

/// Accesses a value from the yaml document, while wrapping errors
pub fn yaml_get_int(key: &str, yaml: &Yaml) -> Result<i64, Error> {
    match yaml[key] {
        Yaml::Integer(int) => Ok(int),
        Yaml::BadValue => Err(Error::MissingKey(key.to_string())),

        _ => Err(Error::WrongKeyType {
            key: key.to_string(),
            expected_type: "integer",
        }),
    }
}

/// Accesses a value from the yaml document, while wrapping errors
pub fn yaml_get_list(key: &str, yaml: &Yaml) -> Result<Vec<Yaml>, Error> {
    match yaml[key] {
        Yaml::Array(ref array) => Ok(array.clone()),
        Yaml::BadValue => Err(Error::MissingKey(key.to_string())),

        _ => Err(Error::WrongKeyType {
            key: key.to_string(),
            expected_type: "list",
        }),
    }
}

/// Accesses a value from the yaml document, while wrapping errors
pub fn yaml_get_date(key: &str, yaml: &Yaml) -> Result<DateTime<FixedOffset>, Error> {
    let raw = match yaml[key] {
        Yaml::String(ref string) => string,
        Yaml::BadValue => return Err(Error::MissingKey(key.to_string())),

        _ => return Err(Error::WrongKeyType {
            key: key.to_string(),
            expected_type: "string",
        }),
    };

    // parse date
    let date = DateTime::parse_from_rfc3339(raw)
        .map_err(|_| Error::InvalidDate(key.to_string()))?;

    Ok(date)
}

/// Annotates errors onto the yaml source code
pub fn yaml_annotate(src: &str, error: Error) -> String {
    match error {
        Error::InvalidYaml(scan_err) => {
            let mut head = 0;

            // find the line end
            let mut lines = 2; // cuz of how stuff works
            for (i, chara) in src.chars().enumerate() {
                if chara == '\n' {
                    if lines == scan_err.marker().line() {
                        head = i;
                        break;
                    }
                    lines += 1;
                }
            }

            let tail = &src[head..];
            let head = &src[..head];
            
            let annotated = format!(
                "{head} ## ERROR: Invalid Yaml: {}{tail}",
                scan_err.info(),
            );

            annotated
        },
        Error::EmptyYaml => "## ERROR: Expected some YAML here...".to_string(),
        Error::NonHashMapDoc => format!("## ERROR: Expected a hashmap YAML doc instead\n{src}"),
        Error::MultipleYamlDocs => format!("## ERROR: Multiple YAML docs found\n{src}"),
        Error::MissingKey(key) => format!("## ERROR: Missing key '{key}'\n\n{src}"),

        // hackiest way to do this, but it's the easiest way as the
        // yaml library doesn't provide spans for each of the keys.
        Error::WrongKeyType { key, expected_type } => {
            // will break on some edge-cases
            let idx = src.find(&format!("{key}:"))
                .unwrap_or_else(|| src.find(&format!("{key}")).unwrap());

            // find the line end
            let mut head = 0;
            for (i, chara) in src.chars().enumerate() {
                if chara == '\n' {
                    if i > idx {
                        head = i;
                        break;
                    }
                }
            }

            let tail = &src[head..];
            let head = &src[..head];
            
            let annotated = format!(
                "{head} ## ERROR: Key of wrong type: expected '{key}' to be a {expected_type}{tail}",
            );

            annotated
        },
        Error::InvalidDate(key) => {
            // will break on some edge-cases
            let idx = src.find(&format!("{key}:"))
                .unwrap_or_else(|| src.find(&format!("{key}")).unwrap());

            // find the line end
            let mut head = 0;
            for (i, chara) in src.chars().enumerate() {
                if chara == '\n' {
                    if i > idx {
                        head = i;
                        break;
                    }
                }
            }

            let tail = &src[head..];
            let head = &src[..head];
            
            let annotated = format!(
                "{head} ## ERROR: Invalid Date{tail}"
            );

            annotated
        },
    }
}
