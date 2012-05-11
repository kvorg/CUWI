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

BEGIN { use_ok( 'CWB::Model::ParamValidator'); }
use Mojo::Parameters;


{
  package Fake::Controller;
  use Mojo::Base -base;

  has 'params';
}

my $p = Mojo::Parameters->new(foo=>'bar', foo=>'baz', zoo=>'full', num=>33);
my $c = Fake::Controller->new(params=> $p);

#my $merged = CWB::Model::ParamValidator::_merge_specs();


my $v;
TODO: {
  local $TODO = 'Rethink and finish ParamValidator';
$v = CWB::Model::ParamValidator::_process
  ($c, validate => { foo => { type => 'ARRAY' }, num => { type => 'scalar'} } );
is($v, undef) or diag (Dumper($v));
$v = CWB::Model::ParamValidator::_process
  ($c, validate => { foo => { type => 'HASH' }, num => { type => 'HASH'} } );
is($v, undef) or diag (Dumper($v));
}
done_testing();
