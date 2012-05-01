#!/usr/bin/env perl
use strict; use warnings;
use lib qw(./lib ../lib ./lib-extra ../lib-extra);
use Test::More;
use Test::Mojo;

$ENV{MOJO_MODE} = 'testing';
use FindBin;
$ENV{MOJO_HOME} = "$FindBin::Bin/../";
# config does not find the correct testing config file when run from script
#$ENV{MOJO_CONFIG} = "$FindBin::Bin/cuwi.testing.json";
$ENV{MOJO_CONFIG} = "$FindBin::Bin/cuwi.json";
require "$ENV{MOJO_HOME}cuwi";

my $t = Test::Mojo->new();
$t->app->log->level('error');

my $corpus = 'cuwi-fr';
$t->get_ok("/cuwi/$corpus")
  ->status_is(200)
  ->content_type_is('text/html;charset=UTF-8')
  ->element_exists('html head title', 'Cuwi corpus: title')
  ->content_like(qr/CUWI search/i, 'Cuwi corpus: main header')
  ->content_like(qr/CUWI test corpus: Latin 1, French, aligned/i, 'Cuwi corpus: corpus name header')
  ->element_exists('html body div[class="form"]', 'Cuwi corpus: form div')
  ->element_exists('html body div[class="form"] form[method="get"][action="/cuwi/' . $corpus . '/search"]',
		   'Cuwi corpus: form element')
  ->element_exists('html body div[class="description"]',
		   'Cuwi corpus: description div')
  ->element_exists('html body div[class="description"] p',
		   'Cuwi corpus: description p')
  ->content_like(qr{This is a test corpus for CUWI},
		 'Cuwi corpus: corpus description text')
  ->element_exists('html body div[class="description"] h2',
		   'Cuwi corpus: description header')
  ->content_like(qr{Attribute Descriptions},
		 'Cuwi corpus: corpus description header text for attributes')
  ->content_like(qr{Structural Attribute Descriptions \(Tags\)},
		 'Cuwi corpus: corpus description header text for structural attributes')
  ->content_like(qr{Peer Corpora},
		 'Cuwi corpus: corpus description header text for peer coprora')
  ->content_like(qr{Statistics},
		 'Cuwi corpus: corpus description header text for statistics')
  ->element_exists('html body div[class="description"] h2 ~ ul',
		   'Cuwi corpus: description > attributes')
  ->element_exists('html body div[class="description"] h2 ~ table[class="stats"]',
		   'Cuwi corpus: description > statistics')
#  ->element_exists('html body div[class="description"] h2[nth-of-type(2)]', 'Cuwi corpus: description headers 2')
;

my @lists = $t->tx->res->dom
  ->at('html body div[class="description"]')->find('h2 ~ ul')->each;
cmp_ok(scalar @lists, '==', 3, 'Cuwi corpus: number of ul in description');

is(scalar @{$lists[0]->children('li')}, 5,
   'Cuwi corpus: attribute list members');
is($lists[0]->at('li')->at('b')->text, 'nword',
   'Cuwi corpus: attribute list member name');
is($lists[0]->at('li')->text, ': Normalised form of the word',
   'Cuwi corpus: attribute list member description');

is(scalar @{$lists[1]->children('li')}, 8,
   'Cuwi corpus: structural attribute list members');
is($lists[1]->at('li')->at('b')->text, 'text',
   'Cuwi corpus: structural attribute list member name');
is($lists[1]->at('li')->text, ': One article from the corpus',
   'Cuwi corpus: structural attribute list member description');

is(scalar @{$lists[2]->children('li')}, 1,
   'Cuwi corpus: peer corpora list members');
is($lists[2]->at('li')->at('a')->{href}, '/cuwi/cuwi-sl',
   'Cuwi corpus: peer corpora list member link');
is($lists[2]->at('li')->at('a')->at('b')->text, 'CUWI-SL',
   'Cuwi corpus: peer corpora list member name');
is($lists[2]->at('li')->at('a')->text, ': CUWI test corpus: UTF-8, Slovene, aligned',
   'Cuwi corpus: peer corpora list member description');

my $table = $t->tx->res->dom
  ->at('html body div[class="description"] h2 ~ table[class="stats"]');
is(scalar @{$table->children('tr')}, 17,
  'Cuwi corpus: statistics table size');

done_testing;
