#!/usr/bin/env perl
use strict; use warnings;
use lib qw(./lib ../lib ./lib-extra ../lib-extra);
use Test::More;
use Test::Mojo;

$ENV{MOJO_MODE} = 'testing';
use FindBin;
$ENV{MOJO_HOME} = "$FindBin::Bin/../";
# config does not find the correct testing config file when run from script
$ENV{MOJO_CONFIG} = "$FindBin::Bin/cuwi.testing.json";
require "$ENV{MOJO_HOME}cuwi";

my $t = Test::Mojo->new();

# welcome page
$t->get_ok('/cuwi')
  ->status_is(200)
  ->content_type_is('text/html;charset=UTF-8')
  ->content_like(qr/CUWI Search/i);
$t->get_ok('/cuwi')
     ->element_exists('h2', 'Cuwi main: header')
     ->text_like('h2 > a' => qr/CUWI Search/, 'Cuwi main: header contents');

# corpus title page

# search option persistance

# kwic layout

# kwic show options

# kwic alignement

# kwic download templates

# context layout

# context show options

# context alignement

# contex download templates

# frequency layout

# frequency show options

# frequency download templates

done_testing;
