# NAME

GDC::Dict - slurp GDC dictionaries into objects

# SYNOPSIS

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

# METHODS

- new($schema\_directory)

    Slurp the yaml files in the schema. Can also set env var `SCHEMADIR`.

- node($label) / nodes(), edge() / edges()
- edges\_by\_type($edge\_type)

    Get all edges with type `$edge_type`.

- edges\_by\_src($node\_label), edges\_by\_dst($node\_label)

    `edges_by_src` returns outgoing edges.
    `edges_by_dst` returns incoming edges.

- $node->name, $node->schema
- $node->property($prop\_name) / $node->properties

    Get property object on `$node` having name `$prop_name`.

- $edge->src / $edge->dst

    Get node that at source end or destination end of the `$edge`.

- $prop->type
- $prop->term

    Term definition for property `$prop`.

- $prop->values

    Array of property `$prop`'s accepted values.

- $prop->value\_set

    Array of property `$props`'s accepted values, as a list of Term objects.
