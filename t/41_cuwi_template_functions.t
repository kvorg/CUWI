#!/usr/bin/env perl
use strict; use warnings;
use lib qw(./lib ../lib ./lib-extra ../lib-extra);
use Test::More;

# tests only those helpers that are not entirely dependent on tx context
# the rest should be covered with tx tests

BEGIN {
  $ENV{MOJO_NO_BONJOUR} = $ENV{MOJO_NO_IPV6} = 1;
  $ENV{MOJO_IOWATCHER}  = 'Mojo::IOWatcher';
  $ENV{MOJO_MODE} = 'testing';
}

use FindBin;
$ENV{MOJO_HOME} = "$FindBin::Bin/../";
# config does not find the correct testing config file when run from script
#$ENV{MOJO_CONFIG} = "$FindBin::Bin/cuwi.testing.json";

use CWB::CUWI;
use CWB::CUWI::Controller;
use CWB::CUWI::Plugin::CI18N;
my $app = CWB::CUWI->new;
$app->log->level('error'); #BUG: still getting info messages
my $c = CWB::CUWI::Controller->new(app=>$app);
my $l = CWB::CUWI::Plugin::CI18N::_Handler->new(namespace => 'CWB::CUWI::I18N');
$c->stash->{i18n} = $l;
#warn ref $c->stash->{i18n};


$c->languages('en');
is $c->l('generic message with args [_*]', 1, 33, 'abc', 2.5 )
  => 'generic message with args 133abc2.5' ,
  "Cuwi 'l' bracket notation consistency with 'en' and AUTO";
is $c->l('generic message ~escapes with args ~[_1~]')
  => 'generic message ~escapes with args [_1]' ,
  "Cuwi 'l' bracket notation escape consistency with 'en' and AUTO";
is $c->l('generic message with bracket arg [_1]', 'abcdef' )
  => 'generic message with bracket arg abcdef' ,
  "Cuwi 'l' l18n operator with a generic message and argument";

$c->languages('en');
is $c->printnum(59) => '59',
  "Cuwi 'printnum' helper as controller operator with lang 'en'";
is $c->l('result_msg_x_matches_retrieved_for', $c->printnum(59) )
  => '<b>59</b> matches for query ' ,
  "Cuwi 'l' l18n operator with 'en'";

$c->languages('sl');
is $c->printnum(59) => '59',
  "Cuwi 'printnum' helper as controller operator with lang 'sl'";
is $c->l('result_msg_x_matches_retrieved_for', $c->printnum(59) )
  => '<b>59</b> zadetkov za poizvedovanje ' ,
  "Cuwi 'l' l18n operator with 'sl'";

done_testing;
__END__

# printnum

is $c->printnum(10000.834) => '10,000.834',
  'Cuwi helper printnum: missing lang - default separators';

# set a language
$c->languages('en');

is $c->printnum(5) => 5,
  'Cuwi helper printnum: low int';
is $c->printnum(-5) => -5, 'Cuwi helper printnum: negative low int';
is $c->printnum(12.7) => 12.7,
  'Cuwi helper printnum: low float';
is $c->printnum(-33.834) => -33.834,
  'Cuwi helper printnum: negative low int';

is $c->printnum(95) => '95',
  'Cuwi helper printnum: low medium int';
is $c->printnum(95.8) => '95.8',
  'Cuwi helper printnum: low medium float';
is $c->printnum(-95) => '-95',
  'Cuwi helper printnum: low medium negative int';
is $c->printnum(-95.8) => '-95.8',
  'Cuwi helper printnum: low medium negative float';

is $c->printnum(10003) => '10,003',
  'Cuwi helper printnum: medium int';
is $c->printnum(10000.834) => '10,000.834',
  'Cuwi helper printnum: medium float';
is $c->printnum(-10003) => '-10,003',
  'Cuwi helper printnum: medium negative int';
is $c->printnum(-10000.834) => '-10,000.834',
  'Cuwi helper printnum: medium negative float';

is $c->printnum(3452234510003) => '3,452,234,510,003',
  'Cuwi helper printnum: large int';
is $c->printnum('67467456710000.834') => '67,467,456,710,000.834',
  'Cuwi helper printnum: large float';
is $c->printnum(-3452234510003) => '-3,452,234,510,003',
  'Cuwi helper printnum: large negative int';
is $c->printnum('-67467456710000.834') => '-67,467,456,710,000.834',
  'Cuwi helper printnum: large negative float';
is $c->printnum(-67467456710000.834) => '-67,467,456,710,000.8',
  'Cuwi helper printnum: large negative float rounded';

# Cuwi helper printbyte

is $c->printbyte(5) => '5 bytes',
  'Cuwi helper printbyte: low positive bytes';
is $c->printbyte(1023) => '1,023 bytes',
  'Cuwi helper printbyte: high positive bytes';
is $c->printbyte(1024) => '1.00 KB',
  'Cuwi helper printbyte: 1 KB';
is $c->printbyte(1536) => '1.50 KB',
  'Cuwi helper printbyte: 1.5 KB';
is $c->printbyte(1024 * 1024 - 1024) => '1,023.00 KB',
  'Cuwi helper printbyte: under 1 MB';
is $c->printbyte(1024 * 1024) => '1.00 MB',
  'Cuwi helper printbyte: 1 MB';

is $c->printbyte(323452345) => '308.47 MB',
  'Cuwi helper printbyte: medium MB';

is $c->printbyte(1024 * 1024 * 1024) => '1.00 GB',
  'Cuwi helper printbyte: 1 GB';

is $c->printbyte(3234534542345) => '3,012.40 GB',
  'Cuwi helper printbyte: high GB';

#fails on negative!

done_testing;
