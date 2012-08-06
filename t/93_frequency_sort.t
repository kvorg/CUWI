#!/usr/bin/env perl
use strict; use warnings;
use lib qw(./lib ../lib ./lib-extra ../lib-extra);
use Test::More skip_all => 'Not yet implemented.';;
use Test::Mojo;
use Mojo::Util 'url_escape';
use POSIX qw(locale_h);

BEGIN {
  $ENV{MOJO_NO_BONJOUR} = $ENV{MOJO_NO_IPV6} = 1;
  $ENV{MOJO_IOWATCHER}  = 'Mojo::IOWatcher';
  $ENV{MOJO_MODE} = 'testing';
}
done_testing();
# __END_

# use FindBin;
# $ENV{MOJO_HOME} = "$FindBin::Bin/../";
# # config does not find the correct testing config file when run from script
# #$ENV{MOJO_CONFIG} = "$FindBin::Bin/cuwi.testing.json";

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
# 				   display => 'wordlist',
# 				   show=>'lemma',
# 				   sort_a=>'match',
# 				   sort_a_att=>'lemma',
# 				   sort_a_order=>'ascending',
# 				   sort_a_direction=>'natural',
# 				   ) )
#   ->status_is(200)
#   ->content_type_is('text/html;charset=UTF-8')
#   ->element_exists('html body div[class="form"] form',
# 		   'Cuwi form options: form')
#   ->element_exists('html body div[class="matches"] table tr[class="total"]',
# 		   'Cuwi wordlist result table header')
#   ->element_exists('html body div[class="matches"] table tr td[class="head"]',
# 		   'Cuwi wordlist result table structure - head')
#   ->element_exists('html body div[class="matches"] table tr td span[class="part"]',
# 		   'Cuwi wordlist result table structure - part')
#   ->element_exists('html body div[class="matches"] table tr td[class="count"]',
# 		   'Cuwi wordlist result table structure - count')
# ;
# my @results =
#   $t->tx->res->dom->find('html body div[class="matches"] table tr')->each($_);
# is(scalar @results, 91 + 1, 'Cuwi wordlist result table: no. of results');
# shift @results; # drop title line
# @results = map {$_->at('span[class="part"] a')->text} @results;

# use locale;
# setlocale(LC_COLLATE, ($c->language));
# my @sorted = sort { $a cmp $b } @results;
# is_deeply(\@results, \@sorted, 'Cuwi wordlist result sort: match noramal');

# # default form setting sort for attribute not shown
# $t->get_ok("/cuwi/$corpus/search" . bq(query => 'a*',
# 				   display => 'wordlist',
# 				   show=>'lemma',
# 				   sort_a=>'match',
# 				   sort_a_att=>'word',
# 				   sort_a_order=>'ascending',
# 				   sort_a_direction=>'natural',
# 				   ) )
#   ->status_is(200)
#   ->content_type_is('text/html;charset=UTF-8')
# ;
# my @results =
#   $t->tx->res->dom->find('html body div[class="matches"] table tr')->each($_);
# is(scalar @results, 91 + 1, 'Cuwi wordlist result table: no. of results');
# shift @results; # drop title line
# @results = map {$_->at('span[class="part"] a')->text} @results;

# use locale;
# setlocale(LC_COLLATE, ($c->language));
# my @sorted = sort { $a cmp $b } @results;
# is_deeply(\@results, \@sorted, 'Cuwi wordlist result sort: match noramal');

# # test other interesting sort options here

# done_testing();
