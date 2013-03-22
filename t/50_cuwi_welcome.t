#!/usr/bin/env perl
use strict; use warnings; use utf8;
use lib qw(./lib ../lib ./lib-extra ../lib-extra);
use Test::More;
use Test::Mojo;
use Data::Dumper;
$Data::Dumper::Indent = 2;

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

# blurb
is($t->tx->res->dom->at('div.description p')->text, 'english', 'Cuwi main: blurb');
my $blurb = $t->app->config->{blurb};
$t->app->config->{blurb} = 'simple';
$t->get_ok('/cuwi')
  ->status_is(200);
is($t->tx->res->dom->at('div.description p')->text, 'simple', 'Cuwi main: blurb simple');
$t->app->config->{blurb} = $blurb;

# corpora
my @corpora = $t->tx->res->dom->at('div.corpora ul')->find('li b')->each;
cmp_ok(scalar @corpora, '==', 4, 'Cuwi main: number of entries');
is($corpora[0]->text, 'cuwi-fr', 'Cuwi main: first corpus name')
  or diag("First corpus name wrong, page was:\n" . $t->_get_content($t->tx));
is($corpora[1]->text, 'cuwi-sl', 'Cuwi main: second corpus name')
  or diag("Second corpus name wrong, page was:\n" . $t->_get_content($t->tx));
is($corpora[-2]->text, 'cuwil10n', 'Cuwi main: one before last corpus entry')
  or diag("One-before-last corpus entry wrong, page was:\n" . $t->_get_content($t->tx));
is($corpora[-1]->text, 'cuwinew', 'Cuwi main: new style group as last entry')
  or diag("New style group name as last entry wrong, page was:\n" . $t->_get_content($t->tx));

my @titles = map { [$_->at('b')->text, $_->at('a')->text] }
  $t->tx->res->dom->at('div.corpora ul')->find('li')->each;
is_deeply(\@titles, [
		     [ 'cuwi-fr' => ': CUWI test corpus: Latin 1, French, aligned' ],
		     [ 'cuwi-sl' => ': CUWI test corpus: UTF-8, Slovene, aligned' ],
		     [ 'cuwil10n' => ': l10n support in groups' ],
		     [ 'cuwinew' => ': New-style group definition' ]
		    ], 'Cuwi main: names and titles')
  or diag("Mains and titles as an array:\n" . Dumper(\@titles));

# # l10n with accept langauge
# $t->tx($t->tx->req->headers->accept_language('sl'))->get_ok('/cuwi');
# $t->text_like('h1 > a' => qr/Iskalnik CUWI/, 'Cuwi main: header contents accept-language l10n')
#   or print $t->_get_content($t->tx);
# is($t->tx->res->dom->at('div.description p')->text, 'slovenščina',
#   'Cuwi main: blurb session l10n');
# @titles = map { [$_->at('b')->text, $_->at('a')->text] }
#   $t->tx->res->dom->at('div.corpora ul')->find('li')->each;
# is_deeply(\@titles, [
# 		     [ 'cuwi-fr' => ': CUWI test corpus: Latin 1, French, aligned' ],
# 		     [ 'cuwi-sl' => ': CUWI test corpus: UTF-8, Slovene, aligned' ],
# 		     [ 'cuwil10n' => ': podpora za l10o skupin' ],
# 		     [ 'cuwinew' => ': New-style group definition' ]
# 		    ], 'Cuwi main: names and titles accept-language l10n')
#   or diag("Mains and titles as an array:\n" . Dumper(\@titles));

# l10n with session
is(0, scalar($t->ua->cookie_jar->find(Mojo::URL->new('http://localhost:3000/')) ),
   'Cuwi main: no session by default');
$t->get_ok('/cuwi/setlang/sl');
my @session = $t->ua->cookie_jar->find(Mojo::URL->new('http://localhost:3000/'));
is(1, scalar @session, 'Cuwi main: session after set language' );
ok($session [0] =~ m/mojolicious=.*---/, 'Cuwi main: session looks sane');
#print 'JAR:' . join(', ', $t->ua->cookie_jar->find(Mojo::URL->new('http://localhost:3000/')));
$t->get_ok('/cuwi');
$t->text_like('h1 > a' => qr/Iskalnik CUWI/, 'Cuwi main: header contents session l10n')
  or print $t->_get_content($t->tx);
is($t->tx->res->dom->at('div.description p')->text, 'slovenščina',
   'Cuwi main: blurb session l10n');
@titles = map { [$_->at('b')->text, $_->at('a')->text] }
  $t->tx->res->dom->at('div.corpora ul')->find('li')->each;
is_deeply(\@titles, [
		     [ 'cuwi-fr' => ': CUWI test corpus: Latin 1, French, aligned' ],
		     [ 'cuwi-sl' => ': CUWI test corpus: UTF-8, Slovene, aligned' ],
		     [ 'cuwil10n' => ': podpora za l10o skupin' ],
		     [ 'cuwinew' => ': New-style group definition' ]
		    ], 'Cuwi main: names and titles session l10n')
  or diag("Mains and titles as an array:\n" . Dumper(\@titles));


# test statistics
SKIP: {
  skip "Missing index stats tests.", 1;
};

done_testing;
