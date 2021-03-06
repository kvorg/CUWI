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

# get info on testing corus
use CWB::Model;
my $rg = 't/corpora/registry';
my $m = CWB::Model->new(registry => $rg);
my $corpus = 'cuwi-fr';
my $c = ${$m->corpora}{$corpus};

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

$t->get_ok("/cuwi/$corpus/search" . bq(query => 'a*'))
  ->status_is(200)
  ->content_type_is('text/html;charset=UTF-8')
  ->element_exists('html body div[class="form"] form',
		   'Cuwi form options: form')
;
my $form = $t->tx->res->dom->at('html body div[class="form"] form');
my @search = @{$form->find('input[name="search"]')->each( sub { shift->{value}; } )};
is(scalar @search, scalar @{$c->attributes},
  'Cuwi form options: number or show radio buttons');
is(($form->at('input[name="search"][checked]') and $form->at('input[name="search"][checked]')->{value}), 'word',
  'Cuwi form options: default search radio button checked');
my @show = @{$form->find('input[name="show"]')->each( sub { shift->{value}; } )};
is(scalar @show, scalar @{$c->attributes},
  'Cuwi form options: number or search check boxes');
is(($form->at('div[class="search"]')->find('input[checked]') and $form->at('div[class="search"]')->find('input[checked]')->first->{value}), 'word',
  'Cuwi form options: default show checkbox checked');


done_testing;

# 55 config and defaults

# 56 module detection

# 60 kwic layout

# 61 kwic show options

# 62 kwic alignement

# 63 kwic download templates

# 70 context layout

# 71 context show options

# 72 context alignement

# 73 context downloads

# 80 cpos layout

# 81 cpos show options

# 82 cpos alignement

# 90 frequency layout
# get layout stuff out of sort tests

# 91 frequency show options

# 92 frequency download templates

