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


use CWB::Model;

my $rg = 't/corpora/registry';
my $m = CWB::Model->new(registry => $rg);
my $sl = ${$m->corpora}{'cuwi-sl'};


my $q = CWB::Model::Query->new(corpus => $sl, model=> $sl->model, ignorecase=>0 );
isa_ok($q, 'CWB::Model::Query', 'Query: direct instantiation');
ok($q->can('rnd'), 'Query->rnd: exported accessor');

my $r;

#sorting with result->sort
$r = $sl->query(query=>'????', show => [qw(word)],
		reduce=>1, rnd=>1, pagesize=>10,
		display => 'kwic', context => 0  );
is_deeply($r->cposlist, [ 1130, 1213, 1323, 1495, 1575, 1905, 2273, 2373, 3071, 3339 ],
 "Result->reduce: 10 fixed random results 1")
  or diag('Wordlist result data first hit was: ' . Dumper($r->cposlist) );

$r = $sl->query(query=>'????', show => [qw(word)],
		reduce=>1, rnd=>1, pagesize=>10,
		display => 'kwic', context => 0,
		sort => { a=> {
			       target => 'match',
			       att => 'word',
			       order => 'ascending'
			      } } );
is_deeply([sort @{$r->cposlist}], [sort (1130, 1213, 1323, 1495, 1575, 1905, 2273, 2373, 3071, 3339)] ,
 "Result->reduce: 10 fixed random results 1 with sort on match")
  or diag('Wordlist result data first hit was: ' . Dumper($r->cposlist) );

$r = $sl->query(query=>'????', show => [qw(word)],
		reduce=>1, rnd=>2, pagesize=>10,
		display => 'kwic', context => 0  );
is_deeply($r->cposlist, [ 85, 869, 1130, 1213, 1575, 2193, 2299, 2373, 2794, 3339 ],
 "Result->reduce: 10 fixed random results 2")
  or diag('Wordlist result data first hit was: ' . Dumper($r->cposlist) );

$r = $sl->query(query=>'????', show => [qw(word)],
		reduce=>1, rnd=>875, pagesize=>10,
		display => 'kwic', context => 0  );
is_deeply($r->cposlist, [ 48, 52, 1002, 1579, 1905, 2273, 2642, 2813, 3321, 3502 ],
 "Result->reduce: 10 fixed random results 3")
  or diag('Wordlist result data first hit was: ' . Dumper($r->cposlist) );

done_testing();
