use lib './gdcdict/lib';
use GDC::Dict;
use JSON::ize;
use URI::Escape;
use YAML::XS;
#use Tie::IxHash;
use strict;

$ENV{SKIPYAML} = qr/_def|metaschema/;
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

my @props = sort {$a->name cmp $b->name}  map { $_->properties } $dict->nodes;

for my $p (@props) {
  my $spec = $propdefs->{PropDefinitions}{$p->name} = {};
  if ($p->type eq 'enum') {
    $spec->{Enum} = [$p->values];
  }
  else {
    $spec->{Type} = $p->type;
  }
  if ($p->req) {
    $spec->{Req} = 1;
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

# open my $gdc, ">gdc-model.yaml" or die $!;
# print $gdc Dump($mdf);
# close $gdc;
# open my $gdcp, ">gdc-model-props.yaml" or die $!;
# print $gdcp Dump($propdefs);
# close $gdcp;

open my $gdct, ">gdc-model-terms.2.yaml" or die $!;
print $gdct Dump($terms);
close $gdct;
1;
