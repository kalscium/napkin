# napkin
> A dead simple cli for incrementally storing quick back-of-the-napkin ideas

# Installation
---
## Compiling Locally
- Have a zig toolchain and git installed before you begin.
- Clone the repo.
  ```sh
  git clone https://github.com/kalscium/napkin.git
  ```
- Enter the directory of the zig version of napkin.
  ```sh
  cd napkin/napkin-zig
  ```
- Compile the binary with your desired optimizations (`Safe`, `Fast` or `Small`).
  ```sh
  zig build -DOptimize=ReleaseSafe
  ```
- The compiled binary should be in `zig-out/bin`
- Add the binary to your path (and rename it to `napkin`) and try it
  out with
  ```sh
  napkin --help
  ```
## Downloading a Pre-Compiled Binary
- Open the releases tab on the this github repo. 
- Find the latest release.
- Download the corresponding binary for you system (`exe` for windows, `x86` or `arm`, etc).
- Add the binary to your path (rename it to `napkin`) and test it out
  ```sh
  napkin --help
  ```

# Basic Usage
---
Napkin is designed to be an incredibly simple yet powerful cli that's
meant to be as frictionless and pain-free as possible. Most if not all
of the design decisions taken are to restrict the scope and keep the
project focused on that one goal. For example, descriptions are not
allowed for edits as at that point, a small git repo would suit your
use better. Napkin is meant to be for quick back-of-then-napkin ideas
that aren't fully planned out nor throught through, but must be written
down nevertheless.

## The Context File
The context file (accessed through running `napkin context`) only
consists of two fields (for now), the `version` field (to prevent
corruption between versions of napkin) and the `napkins` field.

The only field you should really be touching is the `napkins` field,
which is a list of all the known/linked napkin ids that exist (any
napkin that's not in this list is at risk of deletion).

```yaml
version: <latest version> # don't touch this, AT ALL
napkins: [ my-first-napkin, another-example-napkin, yet-another ] # napkins, unlink them to soft 'delete' them
```

### Dumping
Note that, all changes to any of the files napkin manages are all
temporary, even modifications to configuration files like `context.yml` 
and `meta.yml` for individual napkins. This is so, if you mess up
you can just discard the changes you've made to the file by setting
the `dump` field to true.
```yaml
dump: true # discards all changes made to this config file
version: 1.2.3
napkins: "UH OH, SOME CHANGES THAT I DIDN'T WANT TO MAKE!"
oh_no: 12
```

## Napkins
The core feature of the napkin-cli, is, you guessed it, *napkins*.
Stripping away everything, napkins are just a history of file contents
with some extra meta-data (`id`, `description`, `creation-date`).
Unlike a git repo however, each entry in a napkin's content history
is rather insignificant and acts as more of a backup than a ledger
and cannot be described as that would add unnecessary complexity
and friction that would make a git repo more worthwhile. Also
each iteration of the file, stores the ENTIRE file and not just the
changes, though since napkin works with only a SINGLE TEXT file, this
should be no problem.

## Creating Napkins
You can create napkins with the the `napkin new` command, which drops
you into your editor so that you can write down your idea, and once
you've done that, you can save and quit and the program will
then open a `meta.yml` config file for your napkin where you can
specify the description and maybe modify the history. At this point,
if you set the `dump` field to true in the config file, the napkin will
be discarded and there will be no changes made and anything you've
written down for that napkin will be soft 'deleted'. If you don't
choose to dump the napkin, then the `context.yml` config file will
be automatically updated to include the napkin's id (therefore insuring
that it won't be deleted).

## Napkin Metadata Files
Napkin meta-data consists of a few fields, the id of the napkin, the
description of it, the file extension the creation date and the content history;
they should all be pretty self-explainitory.

The content history is a table of all the versions of the contents
of this napkin, with the key of the sub-tables being the UNIX timestamp
of the edit.

The sub-table contains a `fext` field (file-extension)
which is the file extension of the edit, and should not actually be
modified as it would cause corruption, if you wish to change the file
extension of a napkin, then simply change the global `fext` field of
the napkin itself and it should update the `fext` for any new edits
made.
The sub-table also contains a timestamp of when the edit was made.

```yaml
uid: example-napkin
fext: txt
description: an example napkin to demonstrate it's meta-data
creation-iso8601: 2025-02-11T06:36:38.626000+00:00 # utc date of creation
history: # history of versions/edits of this napkin
  1739255798626: # UNIX timestamp
    fext: md # file-extension at the time
    iso8601: 2025-02-11T06:36:38.626000+00:00 # edit date
  1739255810111: # if you remove this from the history, the edit gets deleted
    fext: txt
    iso8601: 2025-02-11T06:36:50.111000+00:00
```

## Cleaning / Deleting Napkins or Edits
Running the `napkin wipe` command wipes all unlinked files from the
napkin home (`~/.napkin`), basically any file that isn't mentioned by
any of the context or metadata yaml files are removed. This has the
side-effect of making removing napkins trivial, all you have to do is
to simply remove the napkin's id from the list of napkins in the
`context.yml` file, and upon the next `napkin wipe` invocation, the
napkin's files will be gone, the same applies to entries in the napkin
history.
