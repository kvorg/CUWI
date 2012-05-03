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
  ->element_exists('html body div[class="form"]', 'Cuwi corpus form: form div')
  ->element_exists('html body div[class="form"] form[method="get"][action="/cuwi/' . $corpus . '/search"]',
		   'Cuwi corpus form: form element')
  ->element_exists('html body div[class="form"] form input[name="query"]',
		   'Cuwi corpus form: form query field')
  ->element_exists('html body div[class="form"] form select[name="peer"]',
		   'Cuwi corpus form: form peer select')
  ->element_exists('html body div[class="form"] form select[name="peer"] option[value="cuwi-sl"]',
		   'Cuwi corpus form: form peer select member')
  ->element_exists('html body div[class="form"] form select[name="peer"] option[value="cuwi-fr"]',
		   'Cuwi corpus form: form peer select member')
  ->element_exists('html body div[class="form"] form input[name="search"][type="radio"][value="word"][checked="checked"]',
		   'Cuwi corpus form: search radio button for word (checked)')
  ->element_exists('html body div[class="form"] form input[name="search"][type="radio"][value="nword"]',
		   'Cuwi corpus form: search radio button for nword')
  ->element_exists('html body div[class="form"] form select[name="within"]',
		   'Cuwi corpus form: within constraint select tag')
  ->element_exists('html body div[class="form"] form select[name="within"] option[value="-"]',
		   'Cuwi corpus form: within constraint select tag default option')
  ->element_exists('html body div[class="form"] form select[name="within"] option[value="s"]',
		   'Cuwi corpus form: within constraint select tag "s" option')
  ->element_exists('html body div[class="form"] form input[name="ignorecase"][value="1"]',
		   'Cuwi corpus form: ignore case checkbox')
  ->element_exists('html body div[class="form"] form input[name="ignorediacritics"][value="1"]',
		   'Cuwi corpus form: ignore diacritics checkbox')
  ->element_exists('html body div[class="form"] form div[class="structs"]',
		   'Cuwi corpus form: structural constraint div')
  ->element_exists('html body div[class="form"] form div[class="structs"] select[name="in-struct"] option[value="text_jezika"]',
		   'Cuwi corpus form: structural constraint select and option')
  ->element_exists('html body div[class="form"] form div[class="structs"] input[name="struct-query"]',
		   'Cuwi corpus form: structural constraint query')
  ->element_exists('html body div[class="form"] form div[class="structs"] select[name="not-align"] option[value="0"]',
		   'Cuwi corpus form: alignement constraint if/unless select')
  ->element_exists('html body div[class="form"] form div[class="show"]',
		   'Cuwi corpus form: show options div')
  ->element_exists('html body div[class="form"] form div[class="show"] input[name="show"][type="checkbox"][value="word"][checked="checked"]',
		   'Cuwi corpus form: show check box for word (checked)')
  ->element_exists('html body div[class="form"] form div[class="show"] input[name="show"][type="checkbox"][value="nword"]',
		   'Cuwi corpus form: show check box for nword')
  ->element_exists('html body div[class="form"] form input[name="align"][type="checkbox"][value="cuwi-sl"]',
		   'Cuwi corpus form: align check box')
  ->element_exists('html body div[class="form"] form input[name="contextsize"][size="2"][value="7"]',
		   'Cuwi corpus form: contextsize field')
  ->element_exists('html body div[class="form"] form select[name="display"] option[value="kwic"]',
		   'Cuwi corpus form: display mode - kwic')
  ->element_exists('html body div[class="form"] form select[name="display"] option[value="paragraphs"]',
		   'Cuwi corpus form: display mode - paragraphs')
  ->element_exists('html body div[class="form"] form select[name="display"] option[value="sentences"]',
		   'Cuwi corpus form: display mode - sentences')
  ->element_exists('html body div[class="form"] form select[name="display"] option[value="wordlist"]',
		   'Cuwi corpus form: display mode - wordlist')
  ->element_exists('html body div[class="form"] form select[name="listing"] option[value="all"]',
		   'Cuwi corpus form: listing mode - all')
  ->element_exists('html body div[class="form"] form select[name="listing"] option[value="sample"]',
		   'Cuwi corpus form: listing mode - sample')
  ->element_exists('html body div[class="form"] form input[name="startfrom"][value="1"][type="hidden"]',
		   'Cuwi corpus form: startfrom (hidden)')
  ->element_exists('html body div[class="form"] form div[class="sort"] select[name="sort_a"]',
		   'Cuwi corpus form: sorting (only trivial)')
  ->element_exists('html body div[class="form"] form input[type="submit"]',
		   'Cuwi corpus form: submit button')
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
