package GDC::Dict;
use v5.10;
use YAML::PP qw/Load LoadFile/;
use JSON::XS;
use Try::Tiny;
use Carp qw/carp/;
use strict;

our $VERSION = "0.4";
our $SKIPYAML= $ENV {SKIPYAML} ? qr/$ENV{SKIPYAML}/ : qr/^_|metaschema/;
our $SKIPTERMS = $ENV{SKIPTERMS};
our $VERBOSE = undef;

sub new {
  my $class = shift;
  my ($schemadir) = @_;
  my $self = {};
  my $SCHEMADIR=$schemadir//$ENV{SCHEMADIR};
  unless ($SCHEMADIR && -d $SCHEMADIR) {
    die "Need valid schemas directory, not '$SCHEMADIR'";
  }
  bless $self, $class;
  $self->{_nodes} = {};
  $self->{_edges} = [];
  $self->{_edges_by_src} = {};
  $self->{_edges_by_dst} = {};
  $self->{_edges_by_type} = {};
  $self->{_terms} = {};
  $self->{_schema_dir} = $SCHEMADIR;
  $self->_parse_terms unless $SKIPTERMS;
  $self->_slurp_dict;
  $self->_parse_edges;
  return $self;
}

sub _slurp_dict {
  my $self = shift;
  opendir my $d, $self->{_schema_dir};
  my @yamls = grep { /yaml$/ && !/$SKIPYAML/} readdir($d);
  for my $yf (@yamls) {
    # say $yf;
    my ($node) = $yf =~ /(.*)\.yaml/;
    my $yt = _read_yaml_file(join('/',$self->{_schema_dir},$yf));
    if (defined $yt) {
      $self->{_nodes}{$node} = GDC::Dict::Node->new($node, $yt, $self );
    }
    else {
      carp "Skipping $yf...";
    }
  }
}

sub node { $_[0]->{_nodes}{$_[1]} }
sub nodes { values %{$_[0]->{_nodes}} }

sub edges { @{$_[0]->{_edges}} }
sub edges_by_src { @{$_[0]->{_edges_by_src}{$_[1]}||[]} }
sub edges_by_dst { @{$_[0]->{_edges_by_dst}{$_[1]}||[]} }
sub edges_by_type { @{$_[0]->{_edges_by_type}{$_[1]}||[]} }
sub edge_by_src { shift->edges_by_src(@_) }
sub edge_by_dst { shift->edges_by_dst(@_) }
sub edge_by_type { shift->edges_by_type(@_) }
#sub links { shift->edges(@_) } # alias edges()

sub term { $_[0]->{_terms}{$_[1]} }
sub terms { values %{$_[0]->{_terms}} }
sub _parse_edges {
  my $self = shift;
  for my $node ($self->nodes) {
    for my $l  (@{$node->schema->{links}}) {
      if (defined $l->{name}) {
	push @{$self->{_edges}}, GDC::Dict::Edge->new($node->name, $l, $self);
      }
      elsif (defined $l->{subgroup}) {
	for my $sl (@{$l->{subgroup}}) {
	  if (defined $sl->{name}) {
	    push @{$self->{_edges}}, GDC::Dict::Edge->new($node->name,$sl, $self);
	  }
	  else {
	    die "Don't understand this subgroup link: ".encode_json($sl);
	  }
	}
      }
      else {
	die "Don't understand this link: ".encode_json($l);
      }
    }
  }
  for my $e (@{$self->{_edges}}) {
    push @{$self->{_edges_by_src}{$e->{_src_name}}}, $e;
    push @{$self->{_edges_by_dst}{$e->{_dst_name}}}, $e;
    push @{$self->{_edges_by_type}{$e->type}}, $e;
  }
  return 1;
}

sub _parse_terms {
  my $self = shift;
  my $yt;
  my @files = ('_terms.yaml','_terms_enum.yaml');
  for my $tyml (@files) {
    my $pth = join('/', $self->{_schema_dir},$tyml);
    if ( -f $pth  ) {
      $yt = LoadFile($pth);
    }
    next unless defined $yt;
    for my $key (keys %$yt) {
      # in the terms yamls, the key is _not_ the term value (i.e., the
      # data).
      next unless ref $yt->{$key};
      # creating the Term object here is setting the key as the term value
      # but this is a placeholder, until the property enums are read
      $self->{_terms}{"$tyml#/$key/common"} = GDC::Dict::Term->new($key => $yt->{$key}{common});
    }
  }
}

sub _read_yaml_file {
  my $yamlfile = shift;
  open my $yf, $yamlfile or die "$yamlfile $!";
  my $ys="";
  # clear comments from ends of lines
  while (<$yf>) {
    chomp;
    s/#[^"]+$//;
    $ys.="$_\n";
  }
  my $yt;
  try {
    return Load($ys);
  } catch {
    carp "$yamlfile: $_";
    return;
  };
}

package GDC::Dict::Node;

sub new {
  my $class = shift;
  my ($name, $schema, $dict) = @_;
  my $self = bless {}, $class;
  $self->{_name} = $name;
  $self->{_schema} = $schema;
  if ($self->schema->{properties}) {
    my @req = $self->schema->{required} && @{$self->schema->{required}};
    my $props = $self->schema->{properties};

    for my $k (keys %{$self->schema->{properties}})  {
      next if (ref $props->{$k} ne 'HASH') ;
      $props->{$k}{required} = grep /^$k$/,@req;
      $self->{_properties}{$k} = GDC::Dict::Property->new($k, $props->{$k}, $dict);
     }
  }
  return $self;
}
sub name { shift->{_name} }
sub schema { shift->{_schema} }
sub properties {values %{shift->{_properties}}}
sub property { $_[0]->{_properties}{$_[1]} }

package GDC::Dict::Property;

sub new {
  my $class = shift;
  my ($name, $schema, $dict) = @_;
  my $self = bless {}, $class;
  $self->{_name} = $name;
  if (ref $schema eq 'HASH') {
    if ($self->{_values} = $schema->{enum}) {
      my @terms;
      for my $val (@{$schema->{enum}}) {
	# note that here, the key _is_ the term value, according
	# to "Gen3"
	my $t;
	if ($schema->{enumDef}) {
	  # there are term defs
	  my $url = $schema->{enumDef}{$val} &&
	    $schema->{enumDef}{$val}{'$ref'}[0];
	  if ($url) {
	    $t = $dict->term($url);
	    $t->{value} = $val;
	  }
	}
	if (!$t) { # didn't have enumDef, or didn't find a term defn in _term
	  $t = GDC::Dict::Term->new($val, {
	    description => "Ad hoc term",
	    termDef => {
	      term => $val,
	      source => "GDC",
	    }});
	  $dict->{_terms}{$val} = $t;
	}
	push @terms, $t if defined $t;
      }
      $self->{_value_set} = \@terms;
    }
    $self->{_required} = !!$schema->{required};
    $self->{_type} = $schema->{type} && (ref $schema->{type} ? join('|',sort @{$schema->{type}}) : $schema->{type});
    $self->{_type} || ($self->{_type} = ($schema->{enum} ? 'enum' : 'not spec'));
    $self->{_term} = ($dict && $dict->{_terms} && $dict->{_terms}{$name}) || ($schema->{term} && ($schema->{'$ref'} || $schema->{term}));

  }
  elsif (ref $schema eq 'ARRAY') {
    if ($name eq '$ref') {
      $self->{_term} = $schema->[0];
    }
  }
  else {
    $self->{_values} = $schema;
  }
  return $self;
}

sub name { shift->{_name} }
sub values { ref $_[0]->{_values} ? @{$_[0]->{_values}} : $_[0]->{_values} }
sub value_set { $_[0]->{_value_set} ? @{$_[0]->{_value_set}} : () }
sub req { $_[0]->{_required} }
sub type { shift->{_type} }
sub term { shift->{_term} }
sub desc { $_[0]->{_term}{description} }
sub cde_id { $_[0]->{_term}{termDef} && $_[0]->{_term}{termDef}{cde_id} }
sub source { $_[0]->{_term}{termDef} && $_[0]->{_term}{termDef}{source} }
    
package GDC::Dict::Edge;

sub new {
  my $class = shift;
  my ($src_name, $link, $dict) = @_;
  my $self = bless {}, $class;
  $self->{_link} = $link;
  $self->{_src_name} = $src_name;
  $self->{_dst_name} = $link->{target_type};
  $self->{_src} = $dict->node( $self->{_src_name} );
  $self->{_dst} = $dict->node( $self->{_dst_name} );
  unless ($self->{_src}) {
    warn "No node object yet for $src_name" if $VERBOSE;
  }
  unless ($self->{_dst}) {
    warn "No node object yet for $$link{target}" if $VERBOSE;
  }
  $self->{_type} = $link->{label};
  return $self;
}

sub name { shift->{_name} }
sub src_name { shift->{_src_name} }
sub dst_name { shift->{_dst_name} }
sub src { shift->{_src} }
sub dst { shift->{_dst} }
sub type { shift->{_type} }
sub schema { shift->{_link} }
sub mult { shift->schema->{multiplicity} }
sub req { shift->schema->{required} }

1;
package GDC::Dict::Term;

sub new {
  my $class = shift;
  my ($value, $def) = @_;
  if (!defined $def || !defined $def->{termDef}) {
    # say STDERR "Term '$value' has no termDef";
    $def = {};
  }
  my $desc = $def->{description};
  $def = $def->{termDef};
  $def->{value} = $value;
  $def->{description} = $desc;
  $def->{term_id} =~ s/\s+$//;
  $def->{cde_id} =~ s/\s+$//;  

  return bless $def, $class;
}

sub value { shift->{value} }
sub term { shift->{term} }
sub desc { $_[0]->{description} }
sub source_id { $_[0]->{term_id} // $_[0]->{cde_id} }
sub source_version { $_[0]->{term_version} // $_[0]->{cde_version} }
sub source { $_[0]->{source} }

1;


=head1 NAME

GDC::Dict - slurp GDC dictionaries into objects

=head1 SYNOPSIS

 $dict = GDC::Dict->new( "gdcdictionary/gdcdictionary/schemas" );
 $n = $dict->node('case');
 @out_edges = $dict->edges_by_src($n->name);
 @in_edges = $dict->edges_by_dst($n->name);
 for (@out_edges) {
   printf "Outgoing edge type '%d' to node type '%d'\n", $_->type, $_->dst;
 }
 @related_to_edges = $dict->edges_by_type('related_to');

 for my $n ($dict->nodes) {
    # do something with node $n
 }
 for my $e ($dict->edges) {
    # do something with edge $e
 }

 $n = ($dict->nodes)[0];
 for my $p ($n->properties) {
   say $p->name;
   say $p->type;
   say $_-> for $p->values;
 }

=head1 METHODS

=over

=item new($schema_directory)

Slurp the yaml files in the schema. Can also set env var C<SCHEMADIR>.

=item node($label) / nodes(), edge() / edges()

=item edges_by_type($edge_type)

Get all edges with type C<$edge_type>.

=item edges_by_src($node_label), edges_by_dst($node_label)

C<edges_by_src> returns outgoing edges.
C<edges_by_dst> returns incoming edges.

=item $node-E<gt>name, $node-E<gt>schema

=item $node-E<gt>property($prop_name) / $node-E<gt>properties

Get property object on C<$node> having name C<$prop_name>.

=item $edge-E<gt>src / $edge-E<gt>dst

Get node that at source end or destination end of the C<$edge>.

=item $prop-E<gt>type

=item $prop-E<gt>term

Term definition for property C<$prop>.

=item $prop-E<gt>values

Array of property C<$prop>'s accepted values.

=item $prop-E<gt>value_set

Array of property C<$props>'s accepted values, as a list of Term objects.

=back

=cut
