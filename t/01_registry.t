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
use CWB::Model;

# Available testing corpora
my $c_num = 2;
my $rg = 't/corpora/registry';

my $m = CWB::Model->new(registry => $rg)
  or BAIL_OUT('Can\'t instantiate the model: check the registry or expect major problems.');

# MISSING:
# test for non-existing registry
# add tests for multiple registry directories
# tests for broken registriy files, missing info files
# add tests for exception handling
# introduce exceptions in tests

isa_ok($m, 'CWB::Model', 'CWB::Model instantiation with testing registry');

my $handler = sub { diag('Model threw exception: ', @_); };
$m->install_exception_handler($handler);
cmp_ok($m->install_exception_handler, '==', $handler, 'Model: set exception handler');

is(scalar keys %{$m->corpora}, $c_num, 'Registry: model acquired testing corpora');
is($m->registry, $rg, 'Registry: model stored registry');
ok(($c_num == grep { $_->isa('CWB::Model::Corpus') } values %{$m->corpora}),
		    'Registry: corpora instantiatiation from registry');
ok(($c_num == grep { $_->isa('CWB::Model::Corpus::Filebased') }
		    values %{$m->corpora}),
		    'Registry: corpora class from registry correct');

done_testing();
