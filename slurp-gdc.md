# NAME

slurp-gdc.pl - Create MDF representing GDC model in gdcdictionary repo

## SYNOPSIS

    $ export SCHEMADIR=gdcdictionary/gdcdictionary/schemas
    # create gdc-model.yaml.new, gdc-model-props.yaml.new, gdc-model-terms.yaml.new
    $ perl slurp-gdc.pl

## DESCRIPTION

`slurp-gdc.pl` reads YAML "Gen3" schema configuration files as provided in
the open source [repo](https://github.com/NCI-GDC/gdcdictionary), and 
converts it into [Model Description File](https://github.com/CBIIT/bento-mdf)
format. Specifically, by default, it reads from a submodule version of the
GDC repo and outputs three files

- gdc-model.yaml.new
- gdc-model-props.yaml.new
- gdc-model-terms.yaml.new

These may need futzing with, depending on the downstream YAML parser, because
of inconsistent escaping of single quotes (apostrophes, e.g.) in the GDC source.

Because the Term definitions have many issues with inconsistent use of single- and 
double-quotes, this script removes any quotes surrounding these definitions and
then precedes every quote character with a backslash before writing to YAML.

# DEPENDENCIES

Use [cpanminus](https://cpanmin.us) as follows to install dependencies:

    $ cpanm JSON::ize URI::Escape YAML::XS YAML::PP JSON::XS Try::Tiny
