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
isa_ok($q, 'CWB::Model::Query', 'Query: direct instantiation:');

# simple/cqp queries
is($q->query('on')->run->QUERY, '[word="on"]',
   'Query: single token to CQP syntax');
is($q->ignorecase(0)->query('on')->run->QUERY, '[word="on"]',
   'Query: single token to CQP syntax');
is($q->query('on je')->run->QUERY, '[word="on"] [word="je"]',
   'Query: two tokens to CQP syntax');
is($q->query(' on , je bil ')->run->QUERY,
   '[word="on"] [word=","] [word="je"] [word="bil"]',
   'Query: multiple tokens and whitespace');
is($q->query('al*   pre? ')->run->QUERY, '[word="al.*"] [word="pre."]',
   'Query: globbing metacharacters');
is($q->query(' ?a??  p*re ')->run->QUERY, '[word=".a.."] [word="p.*re"]',
   'Query: more globbing metacharacters');
is($q->query('on a[]a bil')->run->QUERY,
   '[word="on"] [word="a\[\]a"] [word="bil"]',
   'Query: escape CQP characters');
is($q->query('on [] bil')->run->QUERY, '[word="on"] [] [word="bil"]',
   'Query: empty CQP tokens');
is($q->query('on []? []* bil []{1,3} nje')->run->QUERY,
   '[word="on"] []? []* [word="bil"] []{1,3} [word="nje"]',
   'Query: CQP token modifiers');
is($q->query('~on [lemma="jaz"] bil')->run->QUERY,
   '[word="on"] [lemma="jaz"] [word="bil"]',
   'Query: full CQP tokens');
is($q->query(' [word="al.*"] [word="pre."]')->run->QUERY,
   '[word="al.*"] [word="pre."]',
   'Query: detected CQP');
is($q->query(" + [] 'kdor' sort by word %cd;")->run->QUERY,
   "[] 'kdor' sort by word %cd;",
   'Query: forced CQP');

# query options
is($q->search('lemma')->query('on biti')->run->QUERY,
   '[lemma="on"] [lemma="biti"]', 'Query: search options');
is($q->search('tag')->ignorecase(1)->query('on biti')->run->QUERY,
   '[tag="on" %c] [tag="biti" %c]', 'Query: case option');
is($q->search('word')->ignorediacritics(1)->query('on biti')->run->QUERY,
   '[word="on" %cd] [word="biti" %cd]', 'Query: diacritics options');
is($q->ignorecase(0)->query('on biti')->run->QUERY,
   '[word="on" %d] [word="biti" %d]', 'Query: disabling options');
isa_ok($q->ignorecase(1), 'CWB::Model::Query',
       'Query: setter returns query object');

# query with structural constraint
is ($q->query('+ "a.*" :: match.text_naslov="Pierre.*"')->run->QUERY,
    '"a.*" :: match.text_naslov="Pierre.*"',
    'Query: full CQP query with structural constraint');
is ($q->_mangle_search('Pier?e*'), 'Pier.e.*',
		       'Query: _mangle_search internal function');
is ($q->struct_constraint_query('Pierre*')->struct_constraint_struct('text_naslov')->query('a*')->run->QUERY,
    '[word="a.*" %cd] :: match.text_naslov="Pierre.*"',
    'Query: query with structural constraint');
my $sr = $sl->query(query=>'a*', struct_constraint_query=>'Pierre*', struct_constraint_struct=>'text_naslov');
ok ( (not grep {not $_->{data}{'text_naslov'} =~ m{^Pierre.*} } @{$sr->hits}),
     'Query: query with structural constraint result consistency')
  or diag("CWB::Model::Result structure contained at least one hit with wrong structural attribute:\n" . Dumper($sr));

# query with alignement constraint
my $c_diag;
$sr = $sl->query(query=>'tako', align=>['cuwi-fr'], align_query_corpus=>'*', align_query => 'alors');
is ($sr->QUERY,
    '[word="tako" %c] :CUWI-FR "alors"',
    'Query: default alignement constraint');
$sr = $sl->query(query=>'tako', align=>['cuwi-fr'], align_query_corpus=>'cuwi-fr', align_query => 'alors');
is ($sr->QUERY,
    '[word="tako" %c] :CUWI-FR "alors"',
    'Query: normal alignement constraint');
is ((scalar @{$sr->hits}), 1,
    'Query: alignement constraint result set');
ok ( 1 == scalar (grep { my $a = join(' ', map { $_->[0] } @{$_->{aligns}{'cuwi-fr'}} ); $a =~ m/alors/ or $c_diag = $a } @{$sr->hits}),
    'Query: alignement constraint result set consistency')
    or diag("CWB::Model::Result structure contained at least one hit with wrong aligned corpus match\n(in $c_diag):\n" . Dumper($sr));
$sr = $sl->query(query=>'tako', align=>['cuwi-fr'], align_query_corpus=>'cuwi-fr', align_query_not => 1, align_query => 'alors');
is ($sr->QUERY,
    '[word="tako" %c] :CUWI-FR ! "alors"',
    'Query: query with negative alignement constraint');
is ((scalar @{$sr->hits}), 10,
    'Query: query with negative alignement constraint result set');
ok (not (grep { my $a = join(' ', map { $_->[0] } @{$_->{aligns}{'cuwi-fr'}} ); $a =~ m/alors/ and $c_diag = $a } @{$sr->hits}),
    'Query: negative alignement constraint result set consistency')
    or diag("CWB::Model::Result structure contained at least one hit with wrong aligned corpus match\n(in $c_diag):\n" . Dumper($sr));

# query with within constraint
$sr = $sl->query(query=>'njimi [] ta', within=>'p', ignorecase=>1);
is($sr->QUERY, '[word="njimi" %c] [] [word="ta" %c] within p',
   'Query: full CQP query with "within" constraint');
is($sr->hitno, 1,
   'Query: full CQP query with "within" constraint matching');
$sr = $sl->query(query=>'njimi [] ta', within=>'s', ignorecase=>1);
is($sr->hitno, 0,
   'Query: full CQP query with "within" constraint ignoring');

# query with all constraints
$sr = $sl->query(query=>'njimi [] ta', within=>'p', ignorecase=>1,
		 align=>['cuwi-fr'],
		 align_query_corpus=>'cuwi-fr', align_query => 'eux',
		 struct_constraint_struct=>'text_naslov',
		 struct_constraint_query=>'Mednarodno*');
is($sr->QUERY,
   '[word="njimi" %c] [] [word="ta" %c] :CUWI-FR "eux" :: match.text_naslov="Mednarodno.*" within p',
   'Query: full CQP query with all constraints');
ok((@{$sr->hits} == 1 and ${$sr->hits}[0]{cpos} == 125),
   'Query: full CQP query with all constraints: result')
  or diag("CWB::Model::Result structure was:\n" . Dumper($sr));

sub ignore {
# query with faulty options -> defaults
$q = CWB::Model::Query->new(corpus => $sl, model=> $sl->model,
			    query=>'ar*', search => 'word',
			    within => undef, ignorecase => 'bozo',
			    show => [ qw (fnord bored) ], display => undef,
			    align=>['not_there'],
			    align_query_corpus=>'the_clown', align_query => undef,
			    struct_constraint_struct=>'you_wish',
			    struct_constraint_query=>undef);
isa_ok($q, 'CWB::Model::Query', 'Query: instantiation with faulty options:');
my $r= $q->run;
isa_ok($r, 'CWB::Model::Result', 'Query: query with faulty options returns result');
is_deeply($r,
	  {
	   corpusname => $sl->name,
	   peers => [ [] ],
	   query      => '[word="ar.*"]',
	   QUERY      => '[word="ar.*"]',
	   time       => $r->time,
	   bigcontext => 'paragraphs',
	   table => '1',
	   hits       => $r->hits,
	   distinct   => $r->distinct,
	   hitno      => $r->hitno,
	   aligns     => [],
	   attributes => [[ qw(word) ]],
	   pages      => { single=>1, this=>1 },
	  },
 "Query: query with faulty options defaults check")
  or diag('Wordlist result data was: ' . Dumper($r) );
}

done_testing();
