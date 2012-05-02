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

# welcome page
$t->get_ok('/cuwi')
  ->status_is(200)
  ->content_type_is('text/html;charset=UTF-8')
  ->element_exists('html head title', 'Cuwi main: title')
  ->element_exists('html body h2', 'Cuwi main: header')
  ->text_like('h2 > a' => qr/CUWI Search/, 'Cuwi main: header contents')
;

# corpora
my @corpora = $t->tx->res->dom->at('ul')->find('li b')->each;
cmp_ok(scalar @corpora, '==', 2, 'Cuwi main: number of corpora');
is($corpora[0]->text, 'CUWI-FR', 'Cuwi main: first corpus name');

done_testing;
