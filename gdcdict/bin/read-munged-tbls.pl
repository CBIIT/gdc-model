#!/usr/bin/env perl
#-*-mode: cperl-*-

use v5.10;
use GDC::Dict;
use Digest::MD5 qw/md5_hex/;
use strict;

=head NAME

read-munged-tbls.pl - pull english out of super-secret munging

=head SYNOPSIS

 perl read-munged-tbls.pl ...gdcdictionary/schemas file-of-table-names.txt

output:
 # original_table_name, calculated_md5, calculated_src_name, calculated_edge_type, calculated_dst_name
 edge_023eaa75_ansomudafrsoanwo	023eaa75	annotated_somatic_mutation	data_from	somatic_annotation_workflow
 edge_0b990528_alwopeonsualre	0b990528	alignment_workflow	performed_on	submitted_aligned_reads
 edge_0dbfe500_laleqcfipaoflaleseqcme: no translation
 ...

=cut

my $munge = {};

# arg is schemas dir
$ENV{SCHEMADIR} //= shift() or die "no schemadir";

my $dict = GDC::Dict->new($ENV{SCHEMADIR});

while (<>) {
  chomp;
  my $n=$_;
  my @a = invert_munged($_);
  if (@a) {
    say join("\t", $n,@{$_}{qw/code src edge dst/}) for @a;
  }
  else {
    say "$_: no translation";
  }
}

sub invert_munged {
  my $munged = shift;
  my ($edge,$md5, $code) = split/_/,$munged;
  unless (keys %$munge) {
    my %m;
    for my $n ($dict->nodes) {
      $m{node}{ substr( join('',map { substr($_,0,2) } split /_/,$n->name), 0, 10 ) } = $n->name;
    }
    for my $e ($dict->edges) {
      my $k = substr( join('',map { substr($_,0,2) } split /_/,$e->type), 0, 10 );
      unless ($m{edge}{$k}) {
	$m{edge}{$k} = $e->type;
      }
    }
    $munge = \%m;
  }
  my @ret;
  for my $s (keys %{$munge->{node}}) {
    if ( my ($stem) = $code =~ /^$s(.*)/ ) {
      for my $r (keys %{$munge->{edge}}) {
	if ( my ($d) = $stem =~ /^$r(.*)/ ) {
	  if ( grep /^$d$/, keys %{$munge->{node}} ) {
	    $s = $$munge{node}{$s};
	    $d = $$munge{node}{$d};
	    $r = $$munge{edge}{$r};
	    my $n = "$s$r$d";
	    $n =~ s/_//g;
	    push @ret, { src=>$s, edge=>$r, dst=>$d, code=>substr(md5_hex("edge_$n"), 0,8) };
	  }
	}
      }
    }
  }
  return @ret;
}

1;
