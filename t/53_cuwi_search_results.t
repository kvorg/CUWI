#!/usr/bin/env perl
use strict; use warnings;
use lib qw(./lib ../lib ./lib-extra ../lib-extra);
use Test::More;
use Test::Mojo;
use Mojo::Util 'url_escape';

$ENV{MOJO_MODE} = 'testing';
use FindBin;
$ENV{MOJO_HOME} = "$FindBin::Bin/../";
# config does not find the correct testing config file when run from script
#$ENV{MOJO_CONFIG} = "$FindBin::Bin/cuwi.testing.json";
$ENV{MOJO_CONFIG} = "$FindBin::Bin/cuwi.json";
require "$ENV{MOJO_HOME}cuwi";

my $t = Test::Mojo->new();
$t->app->log->level('error');

sub bq {
  my $query = '?';
  my $x = 1;
  foreach (@_) {
    if ($x) {
      $x = 0;
      $query .= $_ . '=';
    } else {
      $x = 1;
      $query .= $_ . '&';
    }
  }
  $query =~ s/[&=]$//;
  return $query;
}

my $corpus = 'cuwi-fr';
$t->get_ok("/cuwi/$corpus/search" . bq(query => 'a*', display=>'kwic', show=>'word', show=>'tag'))
  ->status_is(200)
  ->content_type_is('text/html;charset=UTF-8')
  ->element_exists('html body div[class="report"]',
		   'Cuwi results: report div')
  ->element_exists('html body div[class="exports"]',
		   'Cuwi results: export div')
  ->element_exists('html body div[class="matches"]',
		   'Cuwi results: matches div')
;
#$t->tx->res->dom->at('html body div[class="report"]');
#$t->tx->res->dom->at('html body div[class="exports"]');
#$t->tx->res->dom->at('html body div[class="matches"]');

$t->get_ok("/cuwi/$corpus/search" . bq(query => 'ar*', display=>'kwic', show=>'word'))
		    ->status_is(200)
		    ->content_type_is('text/html;charset=UTF-8')
;

# $t->get_ok("/cuwi/$corpus/search" . bq(query => '"ar.*" [lemma="d.*"]', display=>'kwic'))
#   ->status_is(200)
#   ->content_type_is('text/html;charset=UTF-8')
# ;



# search option persistence

# kwic layout

# kwic show options

# kwic alignement

# kwic download templates

# context layout

# context show options

# context alignement

# context downloads

# frequency layout

# frequency show options

# frequency download templates

done_testing;
