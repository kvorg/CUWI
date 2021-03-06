#!/usr/bin/env perl
use strict; use warnings; use utf8;
use lib qw(lib ../lib lib-extra ../lib-extra);

use Test::More; # tests => 1;
my $builder = Test::More->builder;
binmode $builder->output,         ":utf8";
binmode $builder->failure_output, ":utf8";
binmode $builder->todo_output,    ":utf8";

use Data::Dumper;
use Mojo::Util qw(html_escape);
$Data::Dumper::Indent = 2;


use CWB::Model;

my $c_num = 2;
my $rg = 't/corpora/registry';
my $m = CWB::Model->new(registry => $rg);
my $sl = ${$m->corpora}{'cuwi-sl'};

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
	   QUERYMODS  => '',
	   warnings  => [],
	   language   => 'sl_SI',
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
is(scalar @{$r->cposlist}, 5,
	  "Query/Result: cpos list length consistency")
  or diag("CWB::Model::Result->cposlist length was:" . scalar @{$r->cposlist});
is_deeply($r->cposlist, [783, 899, 1043, 1119, 3157],
	  "Query/Result: cpos list matches")
  or diag("CWB::Model::Result->cposlist was:\n" . Dumper($r->cposlist));


# result: search opts, ignore case/diacritics)
$r = $sl->query(query=>'a', hitsonly=>1);
is_deeply($r,
	  {
	   corpusname => $sl->name,
	   peers => [ [] ],
	   query      => '[word="a" %c]',
	   QUERY      => '[word="a" %c]',
	   QUERYMODS  => '',
	   warnings  => [],
	   language   => 'sl_SI',
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

$r = $sl->query(query=>'a', showtags=>1);
is_deeply($r->hits->[1]{left}[3], ['</s>'], 'Query/Result: showtags - all')
  or diag('Result fragment with showtags=>1 was: ' . Dumper($r->hits->[1]{left}) );

$r = $sl->query(query=>'Mednarodno', showtags=>1);
is_deeply($r->hits->[0]{match}[0], ["<text naslov=\"Mednarodno pravo prilagojeno boju proti terorizmu. Nasilje in upor v Guantanamu.\" jezika=\"fra_slv\" title=\"Le droit international sacrifi\x{e9} au combat contre le terrorisme. Violence et r\x{e9}sistances \x{e0} Guant\x{e1}namo.\" id=\"LMD298\"><p><s>"], 'Query/Result: showtags - all with attributes')
  or diag('Result fragment with showtags=>1 was: ' . Dumper($r->hits->[0]{match}) );

$r = $sl->query(query=>'Mednarodno', showtags=>[qw(text p s)]);
is_deeply($r->hits->[0]{match}[0], ["<text naslov=\"Mednarodno pravo prilagojeno boju proti terorizmu. Nasilje in upor v Guantanamu.\" jezika=\"fra_slv\" title=\"Le droit international sacrifi\x{e9} au combat contre le terrorisme. Violence et r\x{e9}sistances \x{e0} Guant\x{e1}namo.\" id=\"LMD298\"><p><s>"], 'Query/Result: showtags - specific list with attributes')
  or diag('Result fragment with showtags=>["text", "p", "s"] was: ' . Dumper($r->hits->[0]{match}) );

$r = $sl->query(query=>'Minister', showtags=>1);
is_deeply([$r->hits->[0]{left}[-1], $r->hits->[0]{match}], [ ['</s></p>'], [[ '<p><s>' ], [ 'Minister' ]] ], 'Query/Result: showtags - all with multiple start/end tags')
  or diag('Result fragment with showtags=>1 was: ' . Dumper([$r->hits->[0]{left}[-1], $r->hits->[0]{match}] ));

$r = $sl->query(query=>'Minister', showtags=>['text','p']);
is_deeply([$r->hits->[0]{left}[-1], $r->hits->[0]{match}], [ ['</p>'], [[ '<p>' ], [ 'Minister' ]] ], 'Query/Result: showtags - specific')
  or diag('Result fragment with showtags=>["text","p"] was: ' . Dumper([$r->hits->[0]{left}[-1], $r->hits->[0]{match}] ));

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
	   QUERYMODS  => '',
	   warnings  => [],
	   language   => 'sl_SI',
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
is($r->cposlist, undef,
   "Query/result: display model wordlist - cposlist: empty");
$r = $sl->query(query=>"a*", search => 'word', show => [ qw (word tag) ], display=>'wordlist', ignorecase=>1);
is_deeply($r,
	  {
	   corpusname => $sl->name,
	   peers => [ [] ],
	   query      => '[word="a.*" %c]',
	   QUERY      => '[word="a.*" %c]',
	   QUERYMODS  => '',
	   warnings  => [],
	   language   => 'sl_SI',
	   time       => $r->time,
	   bigcontext => 'paragraphs',
	   table => '1',
	   hits       => [
			  [ [[ 'avgusta', 'Ncmsg' ]], 6],
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

$r = $sl->query(query=>"a*", search => 'word', show => [ qw (word tag) ], display=>'wordlist', ignorecase=>1, maxhits=>5,);
is_deeply($r,
	  {
	   corpusname => $sl->name,
	   peers => [ [] ],
	   query      => '[word="a.*" %c]',
	   QUERY      => '[word="a.*" %c]',
	   QUERYMODS  => '',
	   warnings  => [],
	   language   => 'sl_SI',
	   time       => $r->time,
	   bigcontext => 'paragraphs',
	   table => '1',
	   hits       => [
			  [ [[ 'avgusta', 'Ncmsg' ]], 6],
			  @{$r->hits}[1..38],
			 ],
	   distinct   => 39,
	   hitno      => 59,
	   aligns     => [],
	   attributes => [[ qw(word tag) ]],
	   pages      => { single=>1, this=>1 },
	  },
 "Query/Result: display model wordlist using small maxhits and multiple loops ")
  or diag('Wordlist result data was: ' . Dumper($r) );

# query/result encoding roundtrip (in queries and all display modes)
# MISSING

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



done_testing();
