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

my $c_num = 2;
my $rg = 't/corpora/registry';
my $m = CWB::Model->new(registry => $rg);
my $sl = ${$m->corpora}{'cuwi-sl'};


my $q = CWB::Model::Query->new(corpus => $sl, model=> $sl->model, ignorecase=>0 );
isa_ok($q, 'CWB::Model::Query', 'Query: direct instantiation');

#TODO reloading tests

done_testing();
