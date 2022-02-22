#-*-mode: cperl-*-
use Test::More;
use Test::Warn;
use lib '../lib';
my $t = (-d 't' ? 't' : '.');

our %ENV;
$ENV{SKIPYAML} = qr/^_|metaschema|badyaml/;
use_ok("GDC::Dict");

ok my $dict = GDC::Dict->new( join('/',$t,'samples') );
is_deeply [sort map { $_->name } $dict->nodes], [sort qw/aligned_reads case diagnosis/];
ok $dict->{_terms};
ok my $n = $dict->node('aligned_reads');
isa_ok($n, "GDC::Dict::Node");
ok my ($e) = $dict->edge_by_src($n->name);
isa_ok($e, "GDC::Dict::Edge");
ok !$dict->edge_by_src('boog');
is scalar $dict->edge_by_src('aligned_reads'), 4;
is scalar $dict->edge_by_type('matched_to'), 2;
is scalar $dict->edge_by_src('diagnosis'), 1;
is scalar $dict->edges, 7;



ok my $p = $dict->node('diagnosis')->property('masaoka_stage');
isa_ok($p, "GDC::Dict::Property");
is scalar $p->values, 6;
is $p->term->value, 'masaoka_stage';
#is $p->source, 'caDSR';
#is $p->cde_id, 3952848;

warning_like  { GDC::Dict->new( join('/',$t,'samples','badyaml') ) } [{ carped => qr/case.yaml/ },{ carped => qr/case.yaml/ }];
done_testing();
