#!/usr/bin/env perl
use strict; use warnings; use utf8;
use lib qw(lib ../lib lib-extra ../lib-extra);

use Test::More; # tests => 1;
my $builder = Test::More->builder;
binmode $builder->output,         ":utf8";
binmode $builder->failure_output, ":utf8";
binmode $builder->todo_output,    ":utf8";

use Data::Dumper;
$Data::Dumper::Indent = 2;

# Dependencies
BEGIN { use_ok( 'CWB::Config'); }
BEGIN { use_ok( 'CWB::CQP'); }
BEGIN { use_ok( 'CWB::Model'); }

# Binary dependencies
my $cqp;
if ($CWB::Config::BinDir and -x ($CWB::Config::BinDir . '/cqp')) {
  $cqp = "$CWB::Config::BinDir/cqp";
  ok($cqp, 'cqp executable: found and accessible by CWB::Config');
} else {
  use IO::Dir;
  my @path = split ':', $ENV{PATH};
  foreach my $pd (@path) {
    ($cqp) = grep { m{cqp} and -x "$pd/$_" } IO::Dir->new($pd)->read;
    $cqp = $pd . '/' . $cqp and last if $cqp;
  }
  ok($cqp, 'cqp executable: found and accessible in path');
}
my ($cqp_version) = grep { m{^Version:\s+.*$} }`$cqp -v`;
$cqp_version =~ s{^Version:\s+(.*)$}{$1};
like($cqp_version, qr{^[2-9][.]}, 'cqp executable: version 2.0.0 or later');

done_testing();
