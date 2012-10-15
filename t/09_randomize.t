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
my $r;

#TODO sorting tests: cqp
#TODO sorting tests: cqp + sort

#TODO exceptions with result->sort

#sorting with result->sort
$r = $sl->query(query=>'????', show => [qw(word msd-en)],
		   display => 'wordlist'  );
is($r->QUERY,
   '[word="...." %c]',
   'Query: ? in query');
is($r->language, 'sl_SI', 'Result->language property');
ok($r->can('sort'), 'Result->sort: exported method');

is_deeply($r->hits->[0],  [ [[ 'Leta', 'Ncnsg' ]], 14],
 "Result->sort: wordlist with no sort first")
  or diag('Wordlist result data first hit was: ' . Dumper($r->hits->[0]) );
# Dumper($r->hits) );
is_deeply($r->hits->[-1], [ [[ '1809', 'Mdc' ]], 1],
 "Result->sort: wordlist with no sort last")
  or diag('Wordlist result data last hit was: ' . Dumper($r->hits->[-1]) ); 
# Dumper($r->hits) );

# $r->sort( target=>'match', order=>'ascending', direction=>'reversed', normalize=>1)
$r->sort(target=>'order');
is_deeply($r->hits->[0], [ [[ 'zanj', 'Pp3msa--b' ]], 1],
 "Result->sort: wordlist with default order sort first")
  or diag('Wordlist result data last hit was: ' . Dumper($r->hits->[0]) ); 
# Dumper($r->hits) );
is_deeply($r->hits->[-1],  [ [[ 'Leta', 'Ncnsg' ]], 14],
 "Result->sort: wordlist with default order sort last")
  or diag('Wordlist result data first hit was: ' . Dumper($r->hits->[-1]) );
# Dumper($r->hits) );

$r->sort(target=>'order', normalize=>1);
is_deeply($r->hits->[0], [ [[ '1809', 'Mdc' ]], 1],
 "Result->sort: wordlist with default order, normalized sort first")
  or diag('Wordlist result data last hit was: ' . Dumper($r->hits->[0]) ); 
# Dumper($r->hits) );
is_deeply($r->hits->[-1],  [ [[ 'Leta', 'Ncnsg' ]], 14],
 "Result->sort: wordlist with default order normalized sort last")
  or diag('Wordlist result data first hit was: ' . Dumper($r->hits->[-1]) );
# Dumper($r->hits) );

$r->sort(target=>'order', order=>'descending');
is_deeply($r->hits->[0],  [ [[ 'Leta', 'Ncnsg' ]], 14],
 "Result->sort: wordlist with descending order sort first")
  or diag('Wordlist result data first hit was: ' . Dumper($r->hits->[0]) );
# Dumper($r->hits) );
is_deeply($r->hits->[-1], [ [[ '1809', 'Mdc' ]], 1],
 "Result->sort: wordlist with descending order sort last")
  or diag('Wordlist result data last hit was: ' . Dumper($r->hits->[-1]) ); 
# Dumper($r->hits) );

$r->sort(target=>'match', order=>'ascending');
is_deeply($r->hits->[0],  [ [[ '1809', 'Mdc' ]], 1],
 "Result->sort: wordlist sort on match, default att first")
  or diag('Wordlist result data first hit was: ' . Dumper($r->hits->[0]) );
# Dumper($r->hits) );
is_deeply($r->hits->[-1], [ [[ 'Zelo', 'Rgp' ]], 3],
 "Result->sort: wordlist sort on match, default att last")
  or diag('Wordlist result data last hit was: ' . Dumper($r->hits->[-1]) ); 
# Dumper($r->hits) );

$r->sort(target=>'match', att=>'msd-en', order=>'ascending');
is_deeply($r->hits->[0],  [ [[ 'Bela', 'Agpfsn' ]], 1],
 "Result->sort: wordlist sort on match, att 'msd-en' first")
  or diag('Wordlist result data first hit was: ' . Dumper($r->hits->[0]) );
# Dumper($r->hits) );
is_deeply($r->hits->[-1], [ [[ 'nima', 'Vmpr3s-y' ]], 1],
 "Result->sort: wordlist sort on match, att 'msd-en' last")
  or diag('Wordlist result data last hit was: ' . Dumper($r->hits->[-1]) ); 
# Dumper($r->hits) );

# result->sort with non-wordlist displays
$r = $sl->query(query=>'????', show => [qw(word msd-en)],
		context=>'3 words', display => 'kwic'  );

$r->sort(target=>'match', att=>'word', order=>'ascending', normalize=>1);
is_deeply($r->hits->[0]{match},  [ [ '1909', 'Mdc' ] ],
 "Result->sort: kwic sort on match, att 'word' first")
  or diag('Wordlist result data first hit was: ' . Dumper($r->hits->[0]) );
# Dumper([ map { $_->{match} } @{$r->hits} ]) );
is_deeply($r->hits->[-1]{match},  [ [ 'vsem', 'Pg-msl' ] ],
 "Result->sort: kwic sort on match, att 'word' last")
  or diag('Wordlist result data last hit was: ' . Dumper($r->hits->[-1]) );
# Dumper([ map { $_->{match} } @{$r->hits} ]) );

$r->sort(target=>'match', att=>'msd-en', order=>'ascending', normalize=>1);
is_deeply($r->hits->[0]{match},  [ [ '1909', 'Mdc' ] ],
 "Result->sort: kwic sort on match, att 'msd-en' first")
  or diag('Wordlist result data first hit was: ' . Dumper($r->hits->[0]) );
# Dumper([ map { $_->{match} } @{$r->hits} ]) );
is_deeply($r->hits->[-1]{match},  [ [ 'pred', 'Si' ] ],
 "Result->sort: kwic sort on match, att 'msd-en' last")
  or diag('Wordlist result data last hit was: ' . Dumper($r->hits->[-1]) );
# Dumper([ map { $_->{match} } @{$r->hits} ]) );

$r->sort(target=>'match', att=>'msd-en', order=>'ascending',
	 normalize=>1, direction=>'reversed');
is_deeply($r->hits->[0]{match},  [ [ '1909', 'Mdc' ] ],
 "Result->sort: kwic sort on match, att 'msd-en' first")
  or diag('Wordlist result data first hit was: ' . Dumper($r->hits->[0]) );
# Dumper([ map { $_->{match} } @{$r->hits} ]) );
is_deeply($r->hits->[-1]{match},  [ [ 'ACLU', 'Npmsn' ] ],
 "Result->sort: kwic sort on match, att 'msd-en' last")
  or diag('Wordlist result data first hit was: ' . Dumper($r->hits->[-1]) );
# Dumper([ map { $_->{match} } @{$r->hits} ]) );

$r->sort(target=>'left', att=>'word', order=>'ascending', normalize=>1);
is_deeply($r->hits->[0]{left},  [ [ '1981', 'Mdc' ], [ 'do', 'Sg' ], [ 'oseb', 'Ncfpg'] ],
 "Result->sort: kwic sort on left context, att 'word' first")
  or diag('Wordlist result data first hit was: ' . Dumper($r->hits->[0]) );
# Dumper([ map { $_->{left} } @{$r->hits} ]) );
is_deeply($r->hits->[-1]{left},  [ [ '.', '.' ], [ 'V', 'Sl' ], [ 'začetku', 'Ncmsl'] ],
 "Result->sort: kwic sort on left context, att 'word' last")
  or diag('Wordlist result data last hit was: ' . Dumper($r->hits->[-1]) );
# Dumper([ map { [ map { $_->[0] } @{$_->{left}} ] } @{$r->hits} ]) );

#query with wordlist sort
$r = $sl->query(query=>'????', show => [qw(word msd-en)],
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

# MISSING: tests for virtual corpus result sorting
# MISSING: tests stressing LC_COLLATE

done_testing();
