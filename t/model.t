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

# MISSING:
# test for non-existing registry
# add tests for multiple registry directories
# tests for broken registriy files, missing info files
# add tests for exception handling
# introduce exceptions in tests

isa_ok($m, 'CWB::Model', 'CWB::Model instantiation');

my $handler = sub { diag('Model threw exception: ', @_); };
$m->install_exception_handler($handler);
cmp_ok($m->install_exception_handler, '==', $handler, 'Model: set exception handler');

is(scalar keys %{$m->corpora}, $c_num, 'Model: acquired testing corpora');
is($m->registry, $rg, 'Model: stored registry');
ok(($c_num == grep { $_->isa('CWB::Model::Corpus') } values %{$m->corpora}),
		    'Model: corpora instantiatiation');
ok(($c_num == grep { $_->isa('CWB::Model::Corpus::Filebased') }
		    values %{$m->corpora}),
		    'Model: corpora class');

# Registry file parsing

my $sl = ${$m->corpora}{'cuwi-sl'};
is($sl->name, 'cuwi-sl', 'Corpus: name parsing');
is($sl->NAME, 'CUWI-SL', 'Corpus: id parsing');
is($sl->title, 'CUWI test corpus: UTF-8, Slovene, aligned',
   'Corpus: title parsing');
cmp_ok(scalar @{$sl->attributes}, '==', 6, 'Corpus: attributes parsing');
is_deeply([sort @{$sl->attributes}],
	  [sort qw(word nword lemma msd-en msd-sl tag)],
	  'Corpus: attribute names');
cmp_ok(scalar @{$sl->structures}, '==', 8, 'Corpus: structures parsing');
is_deeply([sort @{$sl->structures}],
	  [sort qw(text text_id text_jezika text_title text_naslov p s seg)],
	  'Corpus: structure names');
ok(scalar @{$sl->structures} == 8, 'Corpus: structures parsing');
is_deeply([sort @{$sl->alignements}],
	  [sort qw(cuwi-fr)],
	  'Corpus: alignement names');
#my $slnw = ${$m->corpora}{'cuwi-sl-noword'};
#isa_ok($slnw, 'CWB::Model::Corpus::Filebased',
#       'CWB::Model::Corpus instantiation');
#cmp_ok(scalar @{$slnw->attributes}, '==', 6, 'Corpus: attributes parsing');
#ok(grep {$_ eq 'word'} @{$slnw->attributes},
#   'Corpus: added missing "word" attribute.');

# Info file parsing

can_ok($sl, qw(tooltip describe));
#  is(${${$m->corpora}{'cuwi-sl'}->{title}{en},
#     'Test corpus for CUWI - Slovene texts aligned with French',
#    'Corpus title, localized');
#  is(${${$m->corpora}{'cuwi-sl'}->{title}{fr},
#     'Testni korpus CUWI - slovenska besedila poravnana s francoščino',
#    'Corpus title, localized, UTF-8');
is($sl->tooltip(attribute => 'nword', 'en'), 'Normalised form of the word',
   'Corpus info: tooltip localizations - attributes');
is($sl->tooltip(attribute => 'nword', 'sl'), 'Normalizirana oblika besede',
   'Corpus info: tooltip localizations - attributes');
is($sl->tooltip(structure => 'text_jezika', 'en'),
   'The language pair of the article',
   'Corpus info: tooltip localizations - structures');
is($sl->tooltip(structure => 'text_jezika', 'sl'), 'Jezikovni par članka',
   'Corpus info: tooltip localizations - structures');
is($sl->describe('en'), "<p>This is a test corpus for CUWI.</p>\n\n",
   'Corpus info: description localization');
is($sl->describe('sl'), "<p>Testni korpus CUWI.</p>\n",
   'Corpus info: description localization');

#infofile: peer corpora/alignement
# MISSING

# Stats via cwb-describe-corpus -s
is_deeply($sl->stats,
	  {
	      tokens => '3733',
	      attributes => ${$sl->stats}{attributes},
	      structures => ${$sl->stats}{structures},
	      alignements => [ [ 'cuwi-fr', '275' ] ],
	  },
   'Corpus stats: statistics via cwb-describe-corpus -s')
    or diag("CWB::Model::Result structure was:\n" . Dumper($sl->stats));


# Query

my $q = CWB::Model::Query->new(corpus => $sl, model=> $sl->model, ignorecase=>0 );
isa_ok($q, 'CWB::Model::Query', 'Query: direct instantiation');

# simple/cqp queries
TODO: {
  local $TODO = 'Fix failure to set options to Query in new';
  is($q->query('on')->run->QUERY, '[word="on"]',
     'Query: single token to CQP syntax');
}
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
$sr = $sl->query(query=>'tako', align=>['cuwi-fr'], align_query_corpus=>'cuwi-fr', align_query => 'alors');
is ($sr->QUERY,
    '[word="tako" %c] :CUWI-FR "alors"',
    'Query: query with alignement constraint');
is ((scalar @{$sr->hits}), 1,
    'Query: query with alignement constraint result set');
ok (not (grep { join(' ', map { $_[0] } @{$_->{aligns}{'cuwi-fr'}}) =~ m/alors/  } @{$sr->hits}),
    'Query: query with alignement constraint result set consistency')
    or diag("CWB::Model::Result structure contained at least one hit with wrong aligned corpus match:\n" . Dumper($sr));
$sr = $sl->query(query=>'tako', align=>['cuwi-fr'], align_query_corpus=>'cuwi-fr', align_query_not => 1, align_query => 'alors');
is ($sr->QUERY,
    '[word="tako" %c] :CUWI-FR ! "alors"',
    'Query: query with negative alignement constraint');
is ((scalar @{$sr->hits}), 10,
    'Query: query with negative alignement constraint result set');

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
ok(@{$sr->hits} == 1 and ${$sr->hits}[0]{data}{cpos} == 125,
   'Query: full CQP query with all constraints: result');

# TODO

# Result
ok(($c_num ==
    grep { $_->query(query=>'a')->isa('CWB::Model::Result') }
    values %{$m->corpora}),
   'Query/Result: instantiation');

# result: search opts, ignore case/diacritics)
my $r = $sl->query(query=>'a');
is_deeply($r,
	  {
	   corpusname => $sl->name,
	   peers => [ [] ],
	   query      => '[word="a" %c]',
	   QUERY      => '[word="a" %c]',
	   time       => $r->time,
	   bigcontext => 'paragraphs',
	   hits       => [
			  {
			   cpos=>783,
			   data=>{
				  'text_id' => 'LMD298',
				  text_jezika => 'fra_slv',
				  text_naslov => 'Mednarodno pravo prilagojeno boju proti terorizmu. Nasilje in upor v Guantanamu.',
				  text_title => "Le droit international sacrifi\é au combat contre le terrorisme. Violence et résistances à Guantánamo.",
				 },
			   aligns=>{},
			   left=>[ ['potrdil'], ['gladovno'], ['stavko'], [','] ],
			   match=>[['a']],
			   right=>[['jo'], ['je'], ['pripisal'], ['le'], ['76'], ['uje']]
			  },
			  @{$r->hits}[1..4],
			 ],
	   hitno      => 5,
	   aligns     => [],
	   attributes => [[]],
	   pages      => { single=>1, this=>1 },
	  }, "Query/Result: default structure test")
  or diag("CWB::Model::Result structure was:\n" . Dumper($r));

# result: search opts, ignore case/diacritics)
my $r = $sl->query(query=>'a', hitsonly=>1);
is_deeply($r,
	  {
	   corpusname => $sl->name,
	   peers => [ [] ],
	   query      => '[word="a" %c]',
	   QUERY      => '[word="a" %c]',
	   time       => $r->time,
	   bigcontext => 'paragraphs',
	   hitno      => 5,
	   aligns     => [],
	   attributes => [[]],
	  }, "Query/Result: hitsonly")
  or diag("CWB::Model::Result structure was:\n" . Dumper($r));
# result: context

cmp_ok(length(join (' ', map{ $_->[0] } @{$sl->query(query=>'a', l_context=>20)->hits->[0]{left}})), '<=', 20,
       'Query/Result: left context size') or
  diag('Left context was: "' . $sl->query(query=>'a', l_context=>20)->hits->[0]{left} . "\"\n");

cmp_ok(length(join (' ', map{ $_->[0] } @{$sl->query(query=>'a', r_context=>3)->hits->[0]{right}})), '<=', 3,
       'Query/Result: right context size') or
  diag('Right context was: "' . $sl->query(query=>'a', r_context=>3)->hits->[0]{right} . "\"\n");

$r = $sl->query(query=>'a', context=>'3 words');
ok((scalar @{$r->hits->[0]{left}} == 3 and scalar @{$r->hits->[0]{right}} == 3),
   'Query/Result: word context') or
  diag('Contexts were: "' .
       join(' ', @{$r->hits->[0]{left}}) . '" (' .
       scalar @{$r->hits->[0]{left}} . '), "' .
       join (' ', @{$r->hits->[0]{right}}) . '" (' .
       scalar @{$r->hits->[0]{right}} . ")\n");

$r = $sl->query(query=>'a', context=>0);
$r = $sl->query(query=>'a', context=>'s');
ok((uc(substr($r->hits->[0]{left}[0][0], 0, 1))
    eq substr($r->hits->[0]{left}[0][0], 0, 1)
    and substr($r->hits->[0]{right}[-1][0], -1, 1) =~ m{[.!?]}),
   'Query/Result: sentence context')  or
  diag('Contexts were: "' . 
       join('", "',
	    join(' ', map { $_->[0] } @{$r->hits->[0]{left}}),
	    join(' ', map { $_->[0] } @{$r->hits->[0]{match}}),
	    join(' ', map { $_->[0] } @{$r->hits->[0]{right}}),
	   )
       . '" with start "'
       . substr($r->hits->[0]{left}[0][0], 0, 1)
       . '" and end "' 
       . substr($r->hits->[0]{right}[-1][0], -1, 1)
       . "\" .\n");

$r = $sl->query(query=>'a', context=>0);
ok((scalar @{$r->hits->[0]{left}} == 0
   and scalar @{$r->hits->[0]{right}} == 0),
   'Query/Result: zero context') or
  diag('Contexts were: "' .
       join('", "',
	    join(' ', map { $_->[0] } @{$r->hits->[0]{left}}),
	    join(' ', map { $_->[0] } @{$r->hits->[0]{match}}),
	    join(' ', map { $_->[0] } @{$r->hits->[0]{right}}),
	   )
       . '".' . "\n");
is($r->bigcontext, 'paragraphs', 'Query/Result: bigcontext detection');

# result: display tests (show, all/sample)
# MISSING

# result: display modes

$r = $sl->query(query=>"a*", search => 'word', show => [ qw (word tag) ], display=>'wordlist', ignorecase=>0);
is_deeply($r,
	  {
	   corpusname => $sl->name,
	   peers => [ [] ],
	   query      => '[word="a.*"]',
	   QUERY      => '[word="a.*"]',
	   time       => $r->time,
	   bigcontext => 'paragraphs',
	   table => '1',
	   hits       => [
			  [ [[ 'avgusta', 'Ncmsg' ]], 6],
			  @{$r->hits}[1..28],
			 ],
	   distinct   => 29,
	   hitno      => 42,
	   aligns     => [],
	   attributes => [[ qw(word tag) ]],
	   pages      => { single=>1, this=>1 },
	  },
 "Query/Result: display model wordlist - default structure test")
  or diag('Wordlist result data was: ' . Dumper($r) );
$r = $sl->query(query=>"a*", search => 'word', show => [ qw (word tag) ], display=>'wordlist', ignorecase=>1);
is_deeply($r,
	  {
	   corpusname => $sl->name,
	   peers => [ [] ],
	   query      => '[word="a.*" %c]',
	   QUERY      => '[word="a.*" %c]',
	   time       => $r->time,
	   bigcontext => 'paragraphs',
	   table => '1',
	   hits       => [
			  [ [[ 'Ali', 'Cc' ]], 6],
			  @{$r->hits}[1..38],
			 ],
	   distinct   => 39,
	   hitno      => 59,
	   aligns     => [],
	   attributes => [[ qw(word tag) ]],
	   pages      => { single=>1, this=>1 },
	  },
 "Query/Result: display model wordlist - default structure test with ignorecase")
  or diag('Wordlist result data was: ' . Dumper($r) );

# query/result encoding roundtrip (in queries and all display modes)
# MISSING

# result: paging

$r = $sl->query(query=>'a*', context=>'3 words', ignorecase=>0, pagesize=>50);
is($r->{hitno}, 42, 'Query/Result: paging to single page: hitno');
is_deeply($r->pages, { single=> 1, this=> 1 },
	  'Query/Result: paging to single page: page info') or
  diag('Paging data was: ' . Dumper($r->pages));
is_deeply($r->pagelist, [ 1 ], 'Query/Result: paging to single page: pagelist') or
  diag('Paging data was: ' . Dumper($r->pagelist));;

$r = $sl->query(query=>'a*', context=>'3 words', ignorecase=>0, pagesize=>40);
is_deeply($r->pages,
	  {
           'next' => 41,
           'prev' => undef,
           'pagesize' => 40,
           'this' => 1
	  },
	  'Query/Result: paging to two pages: first page info') or
  diag('Paging data was: ' . Dumper($r->pages));
is_deeply($r->pagelist, [ 1, 41 ], 'Query/Result: paging to two pages: first page pagelist') or
  diag('Paging data was: ' . Dumper($r->pagelist));;

$r = $sl->query(query=>'a*', context=>'3 words', ignorecase=>0,
		pagesize=>40, startfrom=>41);
is_deeply($r->pages,
	  {
           'next' => undef,
           'prev' => 1,
           'pagesize' => 40,
           'this' => 41
	  },
	  'Query/Result: paging to two pages: second page\'s page info') or
  diag('Paging data was: ' . Dumper($r->pages));
is_deeply($r->pagelist, [ 1, 41 ], 'Query/Result: paging to two pages: second page pagelist') or
  diag('Paging data was: ' . Dumper($r->pagelist));;

$r = $sl->query(query=>'a*', context=>'3 words', ignorecase=>0,
		pagesize=>40, startfrom=>5);
is_deeply($r->pages,
	  {
           'next' => undef,
           'prev' => 1,
           'pagesize' => 40,
           'this' => 5
	  },
	  'Query/Result: paging to two pages: funky intermediate page info') or
  diag('Paging data was: ' . Dumper($r->pages));
is_deeply($r->pagelist, [ 1, 41 ], 'Query/Result: paging to two pages: funky intermediate page pagelist') or
  diag('Paging data was: ' . Dumper($r->pagelist));;

$r = $sl->query(query=>'a*', context=>'3 words', ignorecase=>0, pagesize=>5);
is_deeply($r->pages,
	  {
           'next' => 6,
           'prev' => undef,
           'pagesize' => 5,
           'this' => 1
	  },
	  'Query/Result: paging to multiple pages: first page info') or
  diag('Paging data was: ' . Dumper($r->pages));
is_deeply($r->pagelist, [ 1, 6, 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: first page pagelist') or
  diag('Paging data was: ' . Dumper($r->pagelist));
is_deeply($r->pagelist(3), [ 1, 6, '...', 41 ], 'Query/Result: paging to multiple pages: first page pagelist ellipsis: 3') or
  diag('Paging data was: ' . Dumper( $r->pagelist(3) ));
is_deeply($r->pagelist(4), [ 1, 6, 11, '...', 41 ], 'Query/Result: paging to multiple pages: first page pagelist ellipsis: 4') or
  diag('Paging data was: ' . Dumper( $r->pagelist(4) ));
is_deeply($r->pagelist(5), [ 1, 6, 11, 16, '...', 41 ], 'Query/Result: paging to multiple pages: first page pagelist ellipsis: 5') or
  diag('Paging data was: ' . Dumper( $r->pagelist(5) ));
is_deeply($r->pagelist(6), [ 1, 6, 11, 16, 21, '...', 41 ], 'Query/Result: paging to multiple pages: first page pagelist ellipsis: 6') or
  diag('Paging data was: ' . Dumper( $r->pagelist(6) ));
is_deeply($r->pagelist(8), [ 1, 6, 11, 16, 21, 26, 31, '...', 41 ], 'Query/Result: paging to multiple pages: first page pagelist ellipsis: 8') or
  diag('Paging data was: ' . Dumper( $r->pagelist(8) ));
is_deeply($r->pagelist(9), [ 1, 6, 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: first page pagelist non-ellipsis: 9') or
  diag('Paging data was: ' . Dumper( $r->pagelist(9) ));

$r = $sl->query(query=>'a*', context=>'3 words', ignorecase=>0,
		pagesize=>5, startfrom=>6);
is_deeply($r->pages,
	  {
           'next' => 11,
           'prev' => 1,
           'pagesize' => 5,
           'this' => 6
	  },
	  'Query/Result: paging to multiple pages: second page\'s page info') or
  diag('Paging data was: ' . Dumper($r->pages));
is_deeply($r->pagelist, [ 1, 6, 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: second page pagelist') or
  diag('Paging data was: ' . Dumper($r->pagelist));
is_deeply($r->pagelist(3), [ 1, 6, '...', 41 ], 'Query/Result: paging to multiple pages: second page pagelist ellipsis: 3') or
  diag('Paging data was: ' . Dumper( $r->pagelist(3) ));
is_deeply($r->pagelist(4), [ 1, 6, 11, '...', 41 ], 'Query/Result: paging to multiple pages: second page pagelist ellipsis: 4') or
  diag('Paging data was: ' . Dumper( $r->pagelist(4) ));
is_deeply($r->pagelist(5), [ 1, 6, 11, 16, '...', 41 ], 'Query/Result: paging to multiple pages: second page pagelist ellipsis: 5') or
  diag('Paging data was: ' . Dumper( $r->pagelist(5) ));
is_deeply($r->pagelist(6), [ 1, 6, 11, 16, 21, '...', 41 ], 'Query/Result: paging to multiple pages: second page pagelist ellipsis: 6') or
  diag('Paging data was: ' . Dumper( $r->pagelist(6) ));
is_deeply($r->pagelist(8), [ 1, 6, 11, 16, 21, 26, 31, '...', 41 ], 'Query/Result: paging to multiple pages: second page pagelist ellipsis: 8') or
  diag('Paging data was: ' . Dumper( $r->pagelist(8) ));
is_deeply($r->pagelist(9), [ 1, 6, 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: second page pagelist non-ellipsis: 9') or
  diag('Paging data was: ' . Dumper( $r->pagelist(9) ));

$r = $sl->query(query=>'a*', context=>'3 words', ignorecase=>0,
		pagesize=>5, startfrom=>7);
is_deeply($r->pages,
	  {
           'next' => 12,
           'prev' => 2,
           'pagesize' => 5,
           'this' => 7
	  },
	  'Query/Result: paging to multiple pages: funky intermediate page info') or
  diag('Paging data was: ' . Dumper($r->pages));
is_deeply($r->pagelist, [ 1, 6, 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: funky intermediate pagelist') or
  diag('Paging data was: ' . Dumper($r->pagelist));
is_deeply($r->pagelist(3), [ 1, 6, '...', 41 ], 'Query/Result: paging to multiple pages: funky intermediate pagelist ellipsis: 3') or
  diag('Paging data was: ' . Dumper( $r->pagelist(3) ));
is_deeply($r->pagelist(4), [ 1, 6, 11, '...', 41 ], 'Query/Result: paging to multiple pages: funky intermediate pagelist ellipsis: 4') or
  diag('Paging data was: ' . Dumper( $r->pagelist(4) ));
is_deeply($r->pagelist(5), [ 1, 6, 11, 16, '...', 41 ], 'Query/Result: paging to multiple pages: funky intermediate pagelist ellipsis: 5') or
  diag('Paging data was: ' . Dumper( $r->pagelist(5) ));
is_deeply($r->pagelist(6), [ 1, 6, 11, 16, 21, '...', 41 ], 'Query/Result: paging to multiple pages: funky intermediate pagelist ellipsis: 6') or
  diag('Paging data was: ' . Dumper( $r->pagelist(6) ));
is_deeply($r->pagelist(8), [ 1, 6, 11, 16, 21, 26, 31, '...', 41 ], 'Query/Result: paging to multiple pages: funky intermediate pagelist ellipsis: 8') or
  diag('Paging data was: ' . Dumper( $r->pagelist(8) ));
is_deeply($r->pagelist(9), [ 1, 6, 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: funky intermediate pagelist ellipsis: 9') or
  diag('Paging data was: ' . Dumper( $r->pagelist(9) ));
is_deeply($r->pagelist(10), [ 1, 6, 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: funky intermediate pagelist non-ellipsis: 10') or
  diag('Paging data was: ' . Dumper( $r->pagelist(10) ));


$r = $sl->query(query=>'a*', context=>'3 words', ignorecase=>0,
		pagesize=>5, startfrom=>37);
is_deeply($r->pages,
	  {
           'next' => undef,
           'prev' => 32,
           'pagesize' => 5,
           'this' => 37
	  },
	  'Query/Result: paging to multiple pages: funky late intermediate page info') or
  diag('Paging data was: ' . Dumper($r->pages));
is_deeply($r->pagelist, [ 1, 6, 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: funky late intermediate pagelist') or
  diag('Paging data was: ' . Dumper($r->pagelist));
TODO: {
  local $TODO = 'Clean up ->pagelist to avoid strangeness at 3';
  is_deeply($r->pagelist(3), [ 1, '...', 36, 41 ], 'Query/Result: paging to multiple pages: funky late intermediate pagelist ellipsis: 3') or
    diag('Paging data was: ' . Dumper( $r->pagelist(3) ));
}
is_deeply($r->pagelist(4), [ 1, '...', 31, 36, 41 ], 'Query/Result: paging to multiple pages: funky late intermediate pagelist ellipsis: 4') or
  diag('Paging data was: ' . Dumper( $r->pagelist(4) ));
is_deeply($r->pagelist(5), [ 1, '...', 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: funky late intermediate pagelist ellipsis: 5') or
  diag('Paging data was: ' . Dumper( $r->pagelist(5) ));
is_deeply($r->pagelist(6), [ 1, '...', 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: funky late intermediate pagelist ellipsis: 6') or
  diag('Paging data was: ' . Dumper( $r->pagelist(6) ));
is_deeply($r->pagelist(8), [ 1, '...', 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: funky late intermediate pagelist ellipsis: 8') or
  diag('Paging data was: ' . Dumper( $r->pagelist(8) ));
is_deeply($r->pagelist(9), [ 1, 6, 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: funky late intermediate pagelist non-ellipsis: 9') or
  diag('Paging data was: ' . Dumper( $r->pagelist(9) ));

$r = $sl->query(query=>'a*', context=>'3 words', ignorecase=>0,
		pagesize=>5, startfrom=>36);
is_deeply($r->pages,
	  {
           'next' => 41,
           'prev' => 31,
           'pagesize' => 5,
           'this' => 36
	  },
	  'Query/Result: paging to multiple pages: late page info') or
  diag('Paging data was: ' . Dumper($r->pages));
is_deeply($r->pagelist, [ 1, 6, 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: late pagelist') or
  diag('Paging data was: ' . Dumper($r->pagelist));
TODO: {
  local $TODO = 'Clean up ->pagelist to avoid strangeness at 3';
  is_deeply($r->pagelist(3), [ 1, '...', 36, 41 ], 'Query/Result: paging to multiple pages: late pagelist ellipsis: 3') or
    diag('Paging data was: ' . Dumper( $r->pagelist(3) ));
}
is_deeply($r->pagelist(4), [ 1, '...', 31, 36, 41 ], 'Query/Result: paging to multiple pages: late pagelist ellipsis: 4') or
  diag('Paging data was: ' . Dumper( $r->pagelist(4) ));
is_deeply($r->pagelist(5), [ 1, '...', 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: late pagelist ellipsis: 5') or
  diag('Paging data was: ' . Dumper( $r->pagelist(5) ));
is_deeply($r->pagelist(6), [ 1, '...', 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: late pagelist ellipsis: 6') or
  diag('Paging data was: ' . Dumper( $r->pagelist(6) ));
is_deeply($r->pagelist(8), [ 1, '...', 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: late pagelist ellipsis: 8') or
  diag('Paging data was: ' . Dumper( $r->pagelist(8) ));
is_deeply($r->pagelist(9), [ 1, 6, 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: late pagelist non-ellipsis: 9') or
  diag('Paging data was: ' . Dumper( $r->pagelist(9) ));

$r = $sl->query(query=>'e*', context=>'3 words', ignorecase=>0,
		pagesize=>5, startfrom=>16);
is_deeply($r->pages,
	  {
           'next' => 21,
           'prev' => 11,
           'pagesize' => 5,
           'this' => 16
	  },
	  'Query/Result: paging to multiple pages with funky last page: late page info') or
  diag('Paging data was: ' . Dumper($r->pages));
is_deeply($r->pagelist, [ 1, 6, 11, 16, 21 ], 'Query/Result: paging to multiple pages: funky late page pagelist') or
  diag('Paging data was: ' . Dumper($r->pagelist));
$r = $sl->query(query=>'*e*', context=>'3 words', ignorecase=>0,
		pagesize=>50, startfrom=>1251);
is_deeply($r->pages,
	  {
           'next' => 1301,
           'prev' => 1201,
           'pagesize' => 50,
           'this' => 1251
	  },
	  'Query/Result: paging to many pages with funky last page: late page info') or
  diag('Paging data was: ' . Dumper($r->pages));
is_deeply($r->pagelist(11), [ 1, '...', 901, 951, 1001, 1051,
			      1101, 1151, 1201, 1251, 1301, 1351 ],
	  'Query/Result: paging to many pages: funky late page pagelist elipsis') or
  diag('Paging data was: ' . Dumper($r->pagelist(11)));

# result: check number of hits against 2 or more pages for 0-based page offsets
# MISSING

# result: alignement, alignement encoding

ok(exists($sl->query(query=>'a', align=>['cuwi-fr'])->hits->[0]{aligns}{'cuwi-fr'}),
   'Query/Result: aligned corpus name') or
  diag('Alignement data was: ' .
       Dumper($sl->query(query=>'a', align=>['cuwi-fr'])->hits->[0]{aligns}));

is_deeply($sl->query(query=>'a', align=>['cuwi-fr'])->hits->[0]{aligns}{'cuwi-fr'},
   [
    map { [ $_ ] }
    split (' ', 'Le 2 septembre , un porte-parole du ministère de la défense confirme la grève de la faim , mais la circonscrit à soixante-seize détenus , et il annonce que neuf grévistes sont hospitalisés et alimentés de force') 
   ],
   'Query/Result: aligned corpus whitespace and encoding');


# MISSING

# model reloading
# MISSING

done_testing();
