#!/usr/bin/env perl
use strict; use warnings;
use lib qw(./lib ../lib ./lib-extra ../lib-extra);
use Test::More;
use Test::Mojo;
use Mojo::Util 'url_escape';

BEGIN {
  $ENV{MOJO_NO_BONJOUR} = $ENV{MOJO_NO_IPV6} = 1;
  $ENV{MOJO_IOWATCHER}  = 'Mojo::IOWatcher';
  $ENV{MOJO_MODE} = 'testing';
}

use FindBin;
$ENV{MOJO_HOME} = "$FindBin::Bin/../";
# config does not find the correct testing config file when run from script
#$ENV{MOJO_CONFIG} = "$FindBin::Bin/cuwi.testing.json";

my $t = Test::Mojo->new('CWB::CUWI');
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
  ->element_exists('html body h2',
		   'Cuwi results: h2')
  ->element_exists('html body div[class="form"]',
		   'Cuwi results: form div')
  ->element_exists('html body div[class="report"]',
		   'Cuwi results: report div')
  ->element_exists('html body div[class="exports"]',
		   'Cuwi results: export div')
  ->element_exists('html body div[class="matches"]',
		   'Cuwi results: matches div')
;

is(@{$t->tx->res->dom->at('html body')->find('div[class="nav"]')}, 2,
  'Cuwi results: nav divs');
is(@{$t->tx->res->dom->at('html body div[class="nav"]')->find('a')}, 7,
  'Cuwi results: nav div links');

my $elt;
$elt = $t->tx->res->dom->at('html body div[class="report"]');
like($elt->at('p')->all_text, qr/Matches 1 to 51 out of 239 retrieved for \Q[word="a.*"]\E in \d+(.\d+)? s\./,
   'Cuwi results: report text');

$elt = $t->tx->res->dom->at('html body div[class="exports"]');
like($elt->all_text, qr/Export results.*/,
   'Cuwi results: export text');
cmp_ok(scalar @{$elt->find('a')}, '>=', 2,
   'Cuwi results: export links');
$elt = $t->tx->res->dom->at('html body div[class="matches"]');
# BUG, should be 51
is(scalar @{$elt->at('table')->find('tr')}, 51,
   'Cuwi results: number of matches in kwic');

$t->get_ok("/cuwi/$corpus/search" . bq(query => 'ar*', display=>'kwic', show=>'word'))
  ->status_is(200)
  ->content_type_is('text/html;charset=UTF-8')
;

 $t->get_ok("/cuwi/$corpus/search" . bq(query => '"ar.*" [lemma="d.*"]'))
   ->status_is(200)
   ->content_type_is('text/html;charset=UTF-8')
;

done_testing;
