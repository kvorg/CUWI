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
  ->element_exists('html body div[class="form"]', 'Cuwi corpus: form div')
  ->element_exists('html body div[class="form"] form[method="get"][action="/cuwi/' . $corpus . '/search"]',
		   'Cuwi corpus: form element')
  ->element_exists('html body div[class="form"] form input[name="query"]',
		   'Cuwi corpus: form query field')
  ->element_exists('html body div[class="form"] form select[name="peer"]',
		   'Cuwi corpus: form peer select')
  ->element_exists('html body div[class="form"] form select[name="peer"] option[value="cuwi-sl"]',
		   'Cuwi corpus: form peer select member')
  ->element_exists('html body div[class="form"] form select[name="peer"] option[value="cuwi-fr"]',
		   'Cuwi corpus: form peer select member')
  ->element_exists('html body div[class="form"] form input[name="search"][type="radio"][value="word"][checked="checked"]',
		   'Cuwi corpus: search radio button for word (checked)')
  ->element_exists('html body div[class="form"] form input[name="search"][type="radio"][value="nword"]',
		   'Cuwi corpus: search radio button for nword')
  ->element_exists('html body div[class="form"] form select[name="within"]',
		   'Cuwi corpus: within constraint select tag')
  ->element_exists('html body div[class="form"] form select[name="within"] option[value="-"]',
		   'Cuwi corpus: within constraint select tag default option')
  ->element_exists('html body div[class="form"] form select[name="within"] option[value="s"]',
		   'Cuwi corpus: within constraint select tag "s" option')
;

# search result page

# search option persistence

# kwic layout

# kwic show options

# kwic alignement

# kwic download templates

# context layout

# context show options

# context alignement

# context download templates

# frequency layout

# frequency show options

# frequency download templates

done_testing;
