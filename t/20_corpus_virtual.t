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

$m->virtual(cuwoos => [ 'cuwi-sl', 'cuwi-fr' ], interleaved => 1);
my $virt = ${$m->corpora}{'cuwoos'};
isa_ok($virt, 'CWB::Model::Corpus::Virtual', 'Virtual Corpus: Instantiation');
is($virt->name, 'cuwoos', 'Virtual Corpus: name parsing');
is($virt->NAME, 'CUWOOS', 'Virtual Corpus: id parsing');
is($virt->title, 'Cuwoos', 'Virtual Corpus: title parsing');
is_deeply($virt->attributes,
	  [ qw( word nword lemma msd-en msd-sl tag ) ],
	  "Virtual Corpus: attribute propagation")
  or diag("CWB::Model::Result structure was:\n" . Dumper($virt->attributes));
is_deeply($virt->tooltips,
	  {
	   'attribute' => {
			   'msd-sl' => {
					'en' => 'Morphosyntactic description of the word in Slovene',
					'sl' => "Oblikoskladenjska oznaka besede v sloven\x{161}\x{10d}ini"
				       },
			   'nword' => {
				       'en' => 'Normalised form of the word',
				       'sl' => 'Normalizirana oblika besede'
				      },
			   'lemma' => {
				       'en' => 'Lemma (base form) of the word',
				       'sl' => 'Lema (osnovna oblika) besede'
				      },
			   'msd-en' => {
					'en' => 'Morphosyntactic description of the word in English',
					'sl' => "Oblikoskladenjska oznaka besede v angle\x{161}\x{10d}ini"
				       },
			   'tag' => {
				     'en' => 'TreeTagger PoS tag',
				     'sl' => 'Oblikoskladenjska oznaka TreeTaggerja'
				    }
			  },
	   'structure' => {
			   'text_jezika' => {
					     'en' => 'The language pair of the article',
					     'sl' => "Jezikovni par \x{10d}lanka"
					    },
			   'p' => {
				   'en' => 'Paragraph',
				   'sl' => 'Odstavek'
				  },
			   'text' => {
				      'en' => 'One article from the corpus',
				      'sl' => "Posamezen \x{10d}lanek iz korpusa"
				     },
			   'seg' => {
				     'en' => 'Aligned segment',
				     'sl' => 'Poravnan segment'
				    },
			   'text_naslov' => {
					     'en' => 'Article title in Slovene',
					     'sl' => "Naslov \x{10d}lanka v sloven\x{161}\x{10d}ini"
					    },
			   'text_title' => {
					    'en' => 'Article title in French',
					    'sl' => "Naslov \x{10d}lanka v franco\x{161}\x{10d}ini"
					   },
			   's' => {
				   'en' => 'Sentence',
				   'sl' => 'Stavek'
				  },
			   'text_id' => {
					 'en' => 'Article identifier',
					 'sl' => "Identifikator \x{10d}lanka"
					}
                        }
 },
	  "Virtual Corpus: tooltip propagation")
  or diag("CWB::Model::Virtual->tooltips was:\n" . Dumper($virt->tooltips));
is($virt->tooltip(attribute => 'nword', 'en'), 'Normalised form of the word', 'Virtual Corpus: tooltip call')
    or diag("CWB::Model::Virtual->tooltip(attribute => 'nword', 'en') was:\n" . Dumper($virt->tooltip(attribute => 'nword', 'en') ));

my $r = $virt->query(query=>'a*', pagesize => 6, startfrom => 0, context => '4 words');
is_deeply($r,
	  {
	   corpusname => $virt->name,
	   peers => [ [] ],
	   query      => '[word="a.*" %c]',
	   QUERY      => '[word="a.*" %c]',
	   time       => $r->time,
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
			   left=>[ ['zatirajočim'], ['oblastnikom'], [':'], ['od'] ],
			   match=>[['angleških']],
			   right=>[['sufražetk'], ['leta'], ['1909'], ['do'] ]
			  },
			  @{$r->hits}[1..7],
			 ],
	   hitno      => 326,
	   aligns     => [],
	   attributes => [[ 'word' ]],
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
	   time       => $r->time,
	   # bigcontext => 'paragraphs',
	   hits       => [@{$r->hits}],
	   hitno      => 326,
	   aligns     => [],
	   attributes => [[ 'word' ]],
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
$r = $virt->query(query=>'a*', display=>'wordlist');
is_deeply($r,
	  {
	   corpusname => $virt->name,
	   peers => [ [] ],
	   query      => '[word="a.*" %c]',
	   QUERY      => '[word="a.*" %c]',
	   time       => $r->time,
	   # bigcontext => 'paragraphs',
	   language => [],
	   hits       => [@{$r->hits}],
	   hitno      => 326,
	   aligns     => [],
	   attributes => [[ 'word' ]],
	   table => '1',
	   pages      => { single=>1, this=>1 },
           # a bit unclean
	   distinct   => 156,
	  }, "Virtual Query/Result: wordlist")
  or diag("CWB::Model::Result structure was:\n" . Dumper($r));

#alginement
$r = $virt->query(query=>'a*', display=>'kwic', align=>'cuwi-fr', pagesize=>10);
is_deeply($r,
	  {
	   corpusname => $virt->name,
	   peers => [ [] ],
	   query      => '[word="a.*" %c]',
	   QUERY      => '[word="a.*" %c]',
	   time       => $r->time,
	   # bigcontext => 'paragraphs',
           #language => [],
	   hits       => [@{$r->hits}],
	   hitno      => 326,
	   aligns     => [ 'cuwi-fr' ],
	   attributes => [[ 'word' ]],
	   pages      => { next=>11, prev=>undef, pagesize=> 10, this=>1 },
           # a bit unclean
	   distinct   => 0,
	  }, "Virtual Query/Result: kwic with align")
  or diag("CWB::Model::Result structure was:\n" . Dumper($r));
is_deeply(${$r->hits}[0]{aligns}{'cuwi-fr'}[0][0], 'Des',
	  "Virtual Query/Result: kwic align line start")
  or diag("CWB::Model::Result structure was:\n" . Dumper(${$r->hits}[0]{aligns}{'cuwi-fr'}));

$virt->general_align(1);
$r = $virt->query(query=>'a*', display=>'kwic', align=>1, pagesize=>10);
is_deeply($r,
	  {
	   corpusname => $virt->name,
	   peers => [ [] ],
	   query      => '[word="a.*" %c]',
	   QUERY      => '[word="a.*" %c]',
	   time       => $r->time,
	   # bigcontext => 'paragraphs',
           #language => [],
	   hits       => [@{$r->hits}],
	   hitno      => 326,
	   aligns     => [ 'cuwi-sl', 'cuwi-fr' ],
	   attributes => [[ 'word' ]],
	   pages      => { next=>11, prev=>undef, pagesize=> 10, this=>1 },
           # a bit unclean
	   distinct   => 0,
	  }, "Virtual Query/Result: kwic with general_align")
  or diag("CWB::Model::Result structure was:\n" . Dumper($r));
is_deeply(${$r->hits}[0]{aligns}{'cuwi-fr'}[0][0], 'Des',
	  "Virtual Query/Result: kwic general_align line start")
  or diag("CWB::Model::Result structure was:\n" . Dumper(${$r->hits}[0]{aligns}{'cuwi-fr'}));

#TODO: missing advanced sorting on virtual corpora

done_testing();
