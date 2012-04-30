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
#Missing 'word' attribute checks: disabled (fails in older CWB)
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
done_testing();
