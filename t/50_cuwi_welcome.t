#!/usr/bin/env perl
use strict; use warnings;
use lib qw(./lib ../lib ./lib-extra ../lib-extra);
use Test::More;
use Test::Mojo;

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
#$t->app->log->level('error');

# welcome page
$t->get_ok('/cuwi')
  ->status_is(200)
  ->content_type_is('text/html;charset=UTF-8')
  ->element_exists('html head title', 'Cuwi main: title')
  ->element_exists('html body h1', 'Cuwi main: header')
  ->text_like('h1 > a' => qr/CUWI Search/, 'Cuwi main: header contents')
  or print $t->_get_content($t->tx);
# corpora
my @corpora = $t->tx->res->dom->at('div.corpora ul')->find('li b')->each;
cmp_ok(scalar @corpora, '==', 3, 'Cuwi main: number of entries');
is($corpora[0]->text, 'cuwi-fr', 'Cuwi main: first corpus name')
  or diag("First corpus name wrong, page was:\n" . $t->_get_content($t->tx));
is($corpora[1]->text, 'cuwi-sl', 'Cuwi main: second corpus name')
  or diag("Second corpus name wrong, page was:\n" . $t->_get_content($t->tx));
is($corpora[-1]->text, 'cuwinew', 'Cuwi main: last corpus name')
  or diag("Last corpus (well, entry) name wrong, page was:\n" . $t->_get_content($t->tx));

# test statistics
SKIP: {
  skip "Missing index stats tests.", 1;
};

done_testing;
