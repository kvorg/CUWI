#!/usr/bin/env perl
use strict; use warnings;
use lib qw(./lib ../lib ./lib-extra ../lib-extra);
use Test::More skip_all => 'Not yet implemented.';
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

done_testing();
# exit;
# __END_

# my $t = Test::Mojo->new('CWB::CUWI');
# $t->app->log->level('error');

# # get info on testing corus
# use CWB::Model;
# my $rg = 't/corpora/registry';
# my $m = CWB::Model->new(registry => $rg);
# my $corpus = 'cuwi-fr';
# my $c = ${$m->corpora}{$corpus};

# sub bq {
#   my $query = '?';
#   my $x = 1;
#   foreach (@_) {
#     if ($x) {
#       $x = 0;
#       $query .= $_ . '=';
#     } else {
#       $x = 1;
#       $query .= $_ . '&';
#     }
#   }
#   $query =~ s/[&=]$//;
#   return $query;
# }

# $t->get_ok("/cuwi/$corpus/search" . bq(query => 'a*',
# 				   display => 'wordlist'
# 				   ) )
#   ->status_is(200)
#   ->content_type_is('text/html;charset=UTF-8')
#   ->element_exists('html body div[class="form"] form',
# 		   'Cuwi form options: form')
#   ->element_exists('html body div[class="report"]',
# 		   'Cuwi report div: report')
# ;
# like($t->tx->res->dom->at('html body div[class="report"]')->all_text,
#      qr/Retrieved \d+ distinct matches from the total of \d+ matches from query \[\w+="[^"]+"\] in \d+[.]\d+ s[.]/, 'Cuwi frequency report text');

# done_testing();
