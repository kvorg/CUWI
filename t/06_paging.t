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

my $r = $sl->query(query=>'a*', context=>'3 words', ignorecase=>0, pagesize=>50);
is($r->{hitno}, 42, 'Query/Result: paging to single page: hitno');
is_deeply($r->pages, { single=> 1, this=> 1 },
	  'Query/Result: paging to single page: page info') or
  diag('Paging data was: ' . Dumper($r->pages));
is_deeply($r->pagelist, [ 1 ], 'Query/Result: paging to single page: pagelist') or
  diag('Paging data was: ' . Dumper($r->pagelist));;

$r = $sl->query(query=>'a*', context=>'3 words', ignorecase=>0, pagesize=>40);
is_deeply($r->pages,
	  {
           'next' => 41,
           'prev' => undef,
           'pagesize' => 40,
           'this' => 1
	  },
	  'Query/Result: paging to two pages: first page info') or
  diag('Paging data was: ' . Dumper($r->pages));
is_deeply($r->pagelist, [ 1, 41 ], 'Query/Result: paging to two pages: first page pagelist') or
  diag('Paging data was: ' . Dumper($r->pagelist));;

$r = $sl->query(query=>'a*', context=>'3 words', ignorecase=>0,
		pagesize=>40, startfrom=>41);
is_deeply($r->pages,
	  {
           'next' => undef,
           'prev' => 1,
           'pagesize' => 40,
           'this' => 41
	  },
	  'Query/Result: paging to two pages: second page\'s page info') or
  diag('Paging data was: ' . Dumper($r->pages));
is_deeply($r->pagelist, [ 1, 41 ], 'Query/Result: paging to two pages: second page pagelist') or
  diag('Paging data was: ' . Dumper($r->pagelist));;

$r = $sl->query(query=>'a*', context=>'3 words', ignorecase=>0,
		pagesize=>40, startfrom=>5);
is_deeply($r->pages,
	  {
           'next' => undef,
           'prev' => 1,
           'pagesize' => 40,
           'this' => 5
	  },
	  'Query/Result: paging to two pages: funky intermediate page info') or
  diag('Paging data was: ' . Dumper($r->pages));
is_deeply($r->pagelist, [ 1, 41 ], 'Query/Result: paging to two pages: funky intermediate page pagelist') or
  diag('Paging data was: ' . Dumper($r->pagelist));;

$r = $sl->query(query=>'a*', context=>'3 words', ignorecase=>0, pagesize=>5);
is_deeply($r->pages,
	  {
           'next' => 6,
           'prev' => undef,
           'pagesize' => 5,
           'this' => 1
	  },
	  'Query/Result: paging to multiple pages: first page info') or
  diag('Paging data was: ' . Dumper($r->pages));
is_deeply($r->pagelist, [ 1, 6, 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: first page pagelist') or
  diag('Paging data was: ' . Dumper($r->pagelist));
is_deeply($r->pagelist(3), [ 1, 6, '...', 41 ], 'Query/Result: paging to multiple pages: first page pagelist ellipsis: 3') or
  diag('Paging data was: ' . Dumper( $r->pagelist(3) ));
is_deeply($r->pagelist(4), [ 1, 6, 11, '...', 41 ], 'Query/Result: paging to multiple pages: first page pagelist ellipsis: 4') or
  diag('Paging data was: ' . Dumper( $r->pagelist(4) ));
is_deeply($r->pagelist(5), [ 1, 6, 11, 16, '...', 41 ], 'Query/Result: paging to multiple pages: first page pagelist ellipsis: 5') or
  diag('Paging data was: ' . Dumper( $r->pagelist(5) ));
is_deeply($r->pagelist(6), [ 1, 6, 11, 16, 21, '...', 41 ], 'Query/Result: paging to multiple pages: first page pagelist ellipsis: 6') or
  diag('Paging data was: ' . Dumper( $r->pagelist(6) ));
is_deeply($r->pagelist(8), [ 1, 6, 11, 16, 21, 26, 31, '...', 41 ], 'Query/Result: paging to multiple pages: first page pagelist ellipsis: 8') or
  diag('Paging data was: ' . Dumper( $r->pagelist(8) ));
is_deeply($r->pagelist(9), [ 1, 6, 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: first page pagelist non-ellipsis: 9') or
  diag('Paging data was: ' . Dumper( $r->pagelist(9) ));

$r = $sl->query(query=>'a*', context=>'3 words', ignorecase=>0,
		pagesize=>5, startfrom=>6);
is_deeply($r->pages,
	  {
           'next' => 11,
           'prev' => 1,
           'pagesize' => 5,
           'this' => 6
	  },
	  'Query/Result: paging to multiple pages: second page\'s page info') or
  diag('Paging data was: ' . Dumper($r->pages));
is_deeply($r->pagelist, [ 1, 6, 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: second page pagelist') or
  diag('Paging data was: ' . Dumper($r->pagelist));
is_deeply($r->pagelist(3), [ 1, 6, '...', 41 ], 'Query/Result: paging to multiple pages: second page pagelist ellipsis: 3') or
  diag('Paging data was: ' . Dumper( $r->pagelist(3) ));
is_deeply($r->pagelist(4), [ 1, 6, 11, '...', 41 ], 'Query/Result: paging to multiple pages: second page pagelist ellipsis: 4') or
  diag('Paging data was: ' . Dumper( $r->pagelist(4) ));
is_deeply($r->pagelist(5), [ 1, 6, 11, 16, '...', 41 ], 'Query/Result: paging to multiple pages: second page pagelist ellipsis: 5') or
  diag('Paging data was: ' . Dumper( $r->pagelist(5) ));
is_deeply($r->pagelist(6), [ 1, 6, 11, 16, 21, '...', 41 ], 'Query/Result: paging to multiple pages: second page pagelist ellipsis: 6') or
  diag('Paging data was: ' . Dumper( $r->pagelist(6) ));
is_deeply($r->pagelist(8), [ 1, 6, 11, 16, 21, 26, 31, '...', 41 ], 'Query/Result: paging to multiple pages: second page pagelist ellipsis: 8') or
  diag('Paging data was: ' . Dumper( $r->pagelist(8) ));
is_deeply($r->pagelist(9), [ 1, 6, 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: second page pagelist non-ellipsis: 9') or
  diag('Paging data was: ' . Dumper( $r->pagelist(9) ));

$r = $sl->query(query=>'a*', context=>'3 words', ignorecase=>0,
		pagesize=>5, startfrom=>7);
is_deeply($r->pages,
	  {
           'next' => 12,
           'prev' => 2,
           'pagesize' => 5,
           'this' => 7
	  },
	  'Query/Result: paging to multiple pages: funky intermediate page info') or
  diag('Paging data was: ' . Dumper($r->pages));
is_deeply($r->pagelist, [ 1, 6, 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: funky intermediate pagelist') or
  diag('Paging data was: ' . Dumper($r->pagelist));
is_deeply($r->pagelist(3), [ 1, 6, '...', 41 ], 'Query/Result: paging to multiple pages: funky intermediate pagelist ellipsis: 3') or
  diag('Paging data was: ' . Dumper( $r->pagelist(3) ));
is_deeply($r->pagelist(4), [ 1, 6, 11, '...', 41 ], 'Query/Result: paging to multiple pages: funky intermediate pagelist ellipsis: 4') or
  diag('Paging data was: ' . Dumper( $r->pagelist(4) ));
is_deeply($r->pagelist(5), [ 1, 6, 11, 16, '...', 41 ], 'Query/Result: paging to multiple pages: funky intermediate pagelist ellipsis: 5') or
  diag('Paging data was: ' . Dumper( $r->pagelist(5) ));
is_deeply($r->pagelist(6), [ 1, 6, 11, 16, 21, '...', 41 ], 'Query/Result: paging to multiple pages: funky intermediate pagelist ellipsis: 6') or
  diag('Paging data was: ' . Dumper( $r->pagelist(6) ));
is_deeply($r->pagelist(8), [ 1, 6, 11, 16, 21, 26, 31, '...', 41 ], 'Query/Result: paging to multiple pages: funky intermediate pagelist ellipsis: 8') or
  diag('Paging data was: ' . Dumper( $r->pagelist(8) ));
is_deeply($r->pagelist(9), [ 1, 6, 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: funky intermediate pagelist ellipsis: 9') or
  diag('Paging data was: ' . Dumper( $r->pagelist(9) ));
is_deeply($r->pagelist(10), [ 1, 6, 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: funky intermediate pagelist non-ellipsis: 10') or
  diag('Paging data was: ' . Dumper( $r->pagelist(10) ));


$r = $sl->query(query=>'a*', context=>'3 words', ignorecase=>0,
		pagesize=>5, startfrom=>37);
is_deeply($r->pages,
	  {
           'next' => undef,
           'prev' => 32,
           'pagesize' => 5,
           'this' => 37
	  },
	  'Query/Result: paging to multiple pages: funky late intermediate page info') or
  diag('Paging data was: ' . Dumper($r->pages));
is_deeply($r->pagelist, [ 1, 6, 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: funky late intermediate pagelist') or
  diag('Paging data was: ' . Dumper($r->pagelist));
TODO: {
  local $TODO = 'Clean up ->pagelist to avoid strangeness at 3';
  is_deeply($r->pagelist(3), [ 1, '...', 36, 41 ], 'Query/Result: paging to multiple pages: funky late intermediate pagelist ellipsis: 3') or
    diag('Paging data was: ' . Dumper( $r->pagelist(3) ));
}
is_deeply($r->pagelist(4), [ 1, '...', 31, 36, 41 ], 'Query/Result: paging to multiple pages: funky late intermediate pagelist ellipsis: 4') or
  diag('Paging data was: ' . Dumper( $r->pagelist(4) ));
is_deeply($r->pagelist(5), [ 1, '...', 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: funky late intermediate pagelist ellipsis: 5') or
  diag('Paging data was: ' . Dumper( $r->pagelist(5) ));
is_deeply($r->pagelist(6), [ 1, '...', 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: funky late intermediate pagelist ellipsis: 6') or
  diag('Paging data was: ' . Dumper( $r->pagelist(6) ));
is_deeply($r->pagelist(8), [ 1, '...', 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: funky late intermediate pagelist ellipsis: 8') or
  diag('Paging data was: ' . Dumper( $r->pagelist(8) ));
is_deeply($r->pagelist(9), [ 1, 6, 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: funky late intermediate pagelist non-ellipsis: 9') or
  diag('Paging data was: ' . Dumper( $r->pagelist(9) ));

$r = $sl->query(query=>'a*', context=>'3 words', ignorecase=>0,
		pagesize=>5, startfrom=>36);
is_deeply($r->pages,
	  {
           'next' => 41,
           'prev' => 31,
           'pagesize' => 5,
           'this' => 36
	  },
	  'Query/Result: paging to multiple pages: late page info') or
  diag('Paging data was: ' . Dumper($r->pages));
is_deeply($r->pagelist, [ 1, 6, 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: late pagelist') or
  diag('Paging data was: ' . Dumper($r->pagelist));
TODO: {
  local $TODO = 'Clean up ->pagelist to avoid strangeness at 3';
  is_deeply($r->pagelist(3), [ 1, '...', 36, 41 ], 'Query/Result: paging to multiple pages: late pagelist ellipsis: 3') or
    diag('Paging data was: ' . Dumper( $r->pagelist(3) ));
}
is_deeply($r->pagelist(4), [ 1, '...', 31, 36, 41 ], 'Query/Result: paging to multiple pages: late pagelist ellipsis: 4') or
  diag('Paging data was: ' . Dumper( $r->pagelist(4) ));
is_deeply($r->pagelist(5), [ 1, '...', 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: late pagelist ellipsis: 5') or
  diag('Paging data was: ' . Dumper( $r->pagelist(5) ));
is_deeply($r->pagelist(6), [ 1, '...', 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: late pagelist ellipsis: 6') or
  diag('Paging data was: ' . Dumper( $r->pagelist(6) ));
is_deeply($r->pagelist(8), [ 1, '...', 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: late pagelist ellipsis: 8') or
  diag('Paging data was: ' . Dumper( $r->pagelist(8) ));
is_deeply($r->pagelist(9), [ 1, 6, 11, 16, 21, 26, 31, 36, 41 ], 'Query/Result: paging to multiple pages: late pagelist non-ellipsis: 9') or
  diag('Paging data was: ' . Dumper( $r->pagelist(9) ));

$r = $sl->query(query=>'e*', context=>'3 words', ignorecase=>0,
		pagesize=>5, startfrom=>16);
is_deeply($r->pages,
	  {
           'next' => 21,
           'prev' => 11,
           'pagesize' => 5,
           'this' => 16
	  },
	  'Query/Result: paging to multiple pages with funky last page: late page info') or
  diag('Paging data was: ' . Dumper($r->pages));
is_deeply($r->pagelist, [ 1, 6, 11, 16, 21 ], 'Query/Result: paging to multiple pages: funky late page pagelist') or
  diag('Paging data was: ' . Dumper($r->pagelist));
$r = $sl->query(query=>'*e*', context=>'3 words', ignorecase=>0,
		pagesize=>50, startfrom=>1251);
is_deeply($r->pages,
	  {
           'next' => 1301,
           'prev' => 1201,
           'pagesize' => 50,
           'this' => 1251
	  },
	  'Query/Result: paging to many pages with funky last page: late page info') or
  diag('Paging data was: ' . Dumper($r->pages));
is_deeply($r->pagelist(11), [ 1, '...', 901, 951, 1001, 1051,
			      1101, 1151, 1201, 1251, 1301, 1351 ],
	  'Query/Result: paging to many pages: funky late page pagelist elipsis') or
  diag('Paging data was: ' . Dumper($r->pagelist(11)));

# result: check number of hits against 2 or more pages for 0-based page offsets
# MISSING

done_testing();
