#!/usr/bin/env perl
use strict; use warnings; use utf8;
use lib qw(lib ../lib lib-extra ../lib-extra);

use Test::More; # tests => 1;
my $builder = Test::More->builder;
binmode $builder->output,         ":utf8";
binmode $builder->failure_output, ":utf8";
binmode $builder->todo_output,    ":utf8";

use Data::Dumper;
$Data::Dumper::Indent = 2;

# Dependencies
BEGIN { use_ok( 'CWB::Config'); }
BEGIN { use_ok( 'CWB::CQP'); }
BEGIN { use_ok( 'CWB::Model'); }

# Binary dependencies
my $cqp;
if ($CWB::Config::BinDir and -x ($CWB::Config::BinDir . '/cqp')) {
  $cqp = "$CWB::Config::BinDir/cqp";
  ok($cqp, 'cqp executable: found and accessible by CWB::Config');
} else {
  use IO::Dir;
  my @path = split ':', $ENV{PATH};
  foreach my $pd (@path) {
    ($cqp) = grep { m{cqp} and -x "$pd/$_" } IO::Dir->new($pd)->read;
    $cqp = $pd . '/' . $cqp and last if $cqp;
  }
  ok($cqp, 'cqp executable: found and accessible in path');
}
my ($cqp_version) = grep { m{^Version:\s+.*$} }`$cqp -v`;
$cqp_version =~ s{^Version:\s+(.*)$}{$1};
like($cqp_version, qr{^[2-9][.]}, 'cqp executable: version 2.0.0 or later');
# Available testing corpora
my $c_num = 3;
my $rg = 't/corpora/registry';

# Model

my $m = CWB::Model->new(registry => $rg)
  or BAIL_OUT('Can\'t instantiate the model: check the registry or expect major problems.');

# virtual corpora
$m->virtual(cuwoos => [ 'cuwi-sl', 'cuwi-fr' ], interleaved => 1);
my $virt = ${$m->corpora}{'cuwoos'};
isa_ok($virt, 'CWB::Model::Corpus::Virtual', 'Virtual Corpus: Instantiation');
is($virt->name, 'cuwoos', 'Virtual Corpus: name parsing');
is($virt->NAME, 'CUWOOS', 'Virtual Corpus: id parsing');
is($virt->title, 'Cuwoos', 'Virtual Corpus: title parsing');
my $r = $virt->query(query=>'a*', pagesize => 6, startfrom => 0);
is_deeply($r,
	  {
	   corpusname => $virt->name,
	   peers => [ [] ],
	   query      => '[word="a.*" %c]',
	   QUERY      => '[word="a.*" %c]',
	   # time       => $r->time,
	   # bigcontext => 'paragraphs',
	   hits       => [
			  {
			   subcorpus_name => 'cuwi-sl',
			   cpos=>26,
			   data=>{
				  'text_id' => 'LMD298',
				  text_jezika => 'fra_slv',
				  text_naslov => 'Mednarodno pravo prilagojeno boju proti terorizmu. Nasilje in upor v Guantanamu.',
				  text_title => "Le droit international sacrifi\é au combat contre le terrorisme. Violence et résistances à Guantánamo.",
				 },
			   aligns=>{},
			   left=>[ ['rajočim'], ['oblastnikom'], [':'], ['od'] ],
			   match=>[['angleških']],
			   right=>[['sufražetk'], ['leta'], ['1909'], ['do'], [] ]
			  },
			  @{$r->hits}[1..7],
			 ],
	   hitno      => 326,
	   aligns     => [],
	   attributes => [[]],
	   pages      => {
			  'next' => 7,
			  'prev' => undef,
			  'pagesize' => 6,
			  'this' => 1
			 },
           # a bit unclean
	   distinct   => 0,
	  }, "Virtual Query/Result: default structure test (interleaved)")
  or diag("CWB::Model::Result structure was:\n" . Dumper($r));
#diag(Dumper($virt->subcorpora));
$virt->reload;
$r = $virt->query(query=>'a*', pagesize => 6, startfrom => 7);
is_deeply($r,
	  {
	   corpusname => $virt->name,
	   peers => [ [] ],
	   query      => '[word="a.*" %c]',
	   QUERY      => '[word="a.*" %c]',
	   # time       => $r->time,
	   # bigcontext => 'paragraphs',
	   hits       => [@{$r->hits}],
	   hitno      => 326,
	   aligns     => [],
	   attributes => [[]],
	   pages      => {
			  'next' => 13,
			  'prev' => 1,
			  'pagesize' => 6,
			  'this' => 7
			 },
           # a bit unclean
	   distinct   => 0,
	  }, "Virtual Query/Result: re-query")
  or diag("CWB::Model::Result structure was:\n" . Dumper($r));

done_testing();
