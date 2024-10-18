### rspec_modifier

A tool for modifying the Rspec files in a Rails project by adding a flow tracking start and stop requests code into it.

### Usage

```
Usage: rspec_reader [OPTIONS] --path <PATH> --output <OUTPUT>

Options:
  -f, --files <FILES>    Comma separated names of extension like .rs, .rb, .cpp
  -p, --path <PATH>      Path of the root directory
  -o, --output <OUTPUT>  Path of the output directory
  -h, --help             Print help
  -V, --version          Print version
```
The --path will take the root directory of the Rails project and --output will take the name of output directory which contains the modified Rspec files.
