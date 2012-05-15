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

my $c_num = 2;
my $rg = 't/corpora/registry';
my $m = CWB::Model->new(registry => $rg);
my $sl = ${$m->corpora}{'cuwi-sl'};


my $q = CWB::Model::Query->new(corpus => $sl, model=> $sl->model, ignorecase=>0 );
isa_ok($q, 'CWB::Model::Query', 'Query: direct instantiation');

#TODO sorting tests: cqp
#TODO sorting tests: cqp + sort
#TODO sorting tests: wordlist frequencies
#query with wordlist sort
my $r = $sl->query(query=>'????', show => [qw(word msd-en)],
		   display => 'wordlist',
		 sort => { 
			  a=> {
			       target => 'match',
			       att => 'word',
			       order => 'descending'
			      }
			 }
		   );
#direction => 'reversed'
is($r->QUERY,
   '[word="...." %c]',
   'Query: ? in query');

is_deeply($r->hits->[0],  [ [[ 'Zelo', 'Rgp' ]], 3],
 "Sorting: wordlist with default attribute descending first")
  or diag('Wordlist result data first hit was: ' . Dumper($r->hits->[0]) );
is_deeply($r->hits->[-1], [ [[ '1809', 'Mdc' ]], 1],
 "Sorting: wordlist with default attribute descending last")
  or diag('Wordlist result data last hit was: ' . Dumper($r->hits->[-1]) );

$r = $sl->query(query=>'????', show => [qw(word msd-en)],
		   display => 'wordlist',
		 sort => { 
			  a=> {
			       target => 'match',
			       att => 'msd-en',
			       order => 'ascending'
			      }
			 }
		   );
is_deeply($r->hits->[0],  [ [[ 'Bela', 'Agpfsn' ]], 1],
 "Sorting: wordlist with selected attribute first")
  or diag('Wordlist result data first hit was: ' . Dumper($r->hits->[0]) );
is_deeply($r->hits->[-1], [ [[ 'nima', 'Vmpr3s-y' ]], 1],
 "Sorting: wordlist with selected attribute last")
  or diag('Wordlist result data last hit was: ' . Dumper($r->hits->[-1]) );

$r = $sl->query(query=>'????', show => [qw(word msd-en)],
		   display => 'wordlist',
		 sort => { 
			  a=> {
			       target => 'match',
			       att => 'msd-en',
			       order => 'ascending',
			       direction => 'reversed'
			      }
			 }
		   );
is_deeply($r->hits->[0],  [ [[ 'roke', 'Ncfpa' ]], 1],
 "Sorting: wordlist with selected attribute reversed (atergo) first")
  or diag('Wordlist result data first hit was: ' . Dumper($r->hits->[0]) );
is_deeply($r->hits->[-1], [ [[ 'nima', 'Vmpr3s-y' ]], 1],
 "Sorting: wordlist with selected attribute reversed (atergo) last")
  or diag('Wordlist result data last hit was: ' . Dumper($r->hits->[-1]) );

# MISSING: tests stressing LC_COLLATE

done_testing();
