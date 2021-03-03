# Dox

This directory contains Dox. A Dox is a directory containing source files that will be built into an SSM Document.

Each Dox directory is named after the SSM Document that will be produced from it.
The directory contains a YAML template file (`template.[yaml|yml]`) that is used to build the SSM Document.
This file uses YAML tags specific to this tool to build SSM Documents by including external files.

## Custom YAML Tags

| Tag              | Description                                                          | Usage                      |
|------------------|----------------------------------------------------------------------|----------------------------|
| `!IncludeScript` | include the contents of a file, splitting each line into a list item | `!IncludeScript ./file.sh` |
