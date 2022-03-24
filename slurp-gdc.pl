use lib './gdcdict/lib';
use GDC::Dict;
use JSON::ize;
use URI::Escape;
use YAML::XS;
#use Tie::IxHash;
use strict;

$ENV{SKIPYAML} = qr/_def|metaschema|_term/;
my $schemadir = $ENV{SCHEMADIR} // "gdcdictionary/gdcdictionary/schemas";

my $dict = GDC::Dict->new($schemadir);

my $mdf = {};
#tie %$mdf, 'Tie::IxHash';
my $propdefs = {};
#tie %$propdefs, 'Tie::IxHash';
my $terms = {};
#tie %$terms, 'Tie::IxHash';

$mdf->{Nodes}={};
$mdf->{Relationships} = {};
$propdefs->{PropDefinitions} = {};
$terms->{Terms} = {};

#tie %{$mdf->{Nodes}}, 'Tie::IxHash';
#tie %{$mdf->{Relationships}}, 'Tie::IxHash';

for my $n (sort { $a->name cmp $b->name } $dict->nodes) {
  $mdf->{Nodes}{$n->name} =
    { Props => [sort map {$_->name eq '$ref' ? () : $_->name} $n->properties] };
}

my $edges = {};
for my $e ($dict->edges) {
  push @{$edges->{$e->type}}, $e;
}

for my $t (sort keys %$edges) {
  my @edges = @{$edges->{$t}};
  my $spec = $mdf->{Relationships}{$t} = {};
  $spec->{Mul} = $edges[0]->mult;
  $spec->{Req} = 1 if $edges[0]->req;
  $spec->{Props} = undef;
  $spec->{Ends} = [ map {
    { Src => $_->src->name,
	Dst => $_->dst->name }
  } @edges ];
}

my %props;
for my $n ($dict->nodes) {
  for my $p ($n->properties) {
    push @{$props{$p->name}}, $n;
  }
}
my @props = sort {$a->name cmp $b->name}  map { $_->properties } $dict->nodes;

for my $prop (sort keys %props) {
  my $dotted = !!( @{$props{$prop}} > 1 );
  for my $n (sort {$a->name cmp $b->name} @{$props{$prop}}) {
    my $pname = $dotted ? $n->name.".$prop" : $prop;
    my $p = $n->property($prop);
    my $spec = $propdefs->{PropDefinitions}{$pname} = {};
    if ($p->type eq 'enum') {
      $spec->{Enum} = [$p->values];
    }
    else {
      
      $spec->{Type} = ($p->type eq 'not spec' ? 'TBD' : $p->type)
    }
    if ($p->req) {
      $spec->{Req} = 1;
    }
  }
}


for my $t (sort {$a->value cmp $b->value} $dict->terms) {
  $terms->{Terms}{$t->value} = {
    origin => $t->source,
    origin_id => $t->source_id,
    origin_version => $t->source_version,
    value => $t->{term},
    origin_definition => uri_escape($t->desc),
  }
}

open my $gdc, ">gdc-model.yaml.new" or die $!;
print $gdc Dump($mdf);
close $gdc;
open my $gdcp, ">gdc-model-props.yaml.new" or die $!;
print $gdcp Dump($propdefs);
close $gdcp;

open my $gdct, ">gdc-model-terms.yaml.new" or die $!;
print $gdct Dump($terms);
close $gdct;
1;


=head1 NAME

slurp-gdc.pl - Create MDF representing GDC model in gdcdictionary repo

=head2 SYNOPSIS

 $ export SCHEMADIR=gdcdictionary/gdcdictionary/schemas
 # create gdc-model.yaml.new, gdc-model-props.yaml.new, gdc-model-terms.yaml.new
 $ perl slurp-gdc.pl

=head2 DESCRIPTION

C<slurp-gdc.pl> reads YAML "Gen3" schema configuration files as provided in
the open source L<repo|https://github.com/NCI-GDC/gdcdictionary>, and 
converts it into L<Model Description File|https://github.com/CBIIT/bento-mdf>
format. Specifically, by default, it reads from a submodule version of the
GDC repo and outputs three files

=over

=item * gdc-model.yaml.new

=item * gdc-model-props.yaml.new

=item * gdc-model-terms.yaml.new

=back

These may need futzing with, depending on the downstream YAML parser, because
of inconsistent escaping of single quotes (apostrophes, e.g.) in the GDC source.

Because the Term definitions have many issues of this type, this
script just url-escapes the term definitions before writing them to
the term.yaml file (see L<./model-desc/gdc-model-terms.yaml>). Need
to unescape these before using the text downstream.

=head1 DEPENDENCIES

Use L<cpanminus|https://cpanmin.us> as follows to install dependencies:

 $ cpanm JSON::ize URI::Escape YAML::XS YAML::PP JSON::XS Try::Tiny

=cut
