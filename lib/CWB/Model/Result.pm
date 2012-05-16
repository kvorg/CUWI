package CWB::Model::Result;

use Mojo::Base -base;
use Carp qw(croak cluck);

has [qw(query QUERY time distinct cpos next prev reduce table bigcontext corpusname)] ;
has hitno => 0;
has pages => sub { return {} } ;
has [qw(hits attributes aligns peers)]  => sub { return [] } ;

# function borrowed from List::Moreutils
sub _firstidx (&@) {
    my $f = shift;
    for my $i (0 .. $#_) {
        local *_ = \$_[$i];
        return $i if $f->();
    }
    return -1;
}

sub pagelist {
  my $self = shift;
  return [ 1 ] if ${$self->pages}{single} ; #shortcut
  my $page = 1;
  my @pages;
  if (not @_) { #all pages
    while ($page < $self->hitno) {
      push @pages, $page;
      $page += ${$self->pages}{pagesize};
    }
  } else {
    my $maxpages = shift;
    $maxpages--;                        #we produce one more
    $maxpages = 2 unless $maxpages > 2; #not usefull to produce less than 3
    $page = (${$self->pages}{this}
	     - (${$self->pages}{this} % ${$self->pages}{pagesize}))
      - int($maxpages / 2) * ${$self->pages}{pagesize} + 1;
    # if near beginning
    $page = 1 if $page < 1;  # near beginning
    my $lastpage  = $page + $maxpages * ${$self->pages}{pagesize};
    my $finalpage = $self->hitno + 1 -
      ($self->hitno % ${$self->pages}{pagesize});
    $lastpage = $finalpage 
      if $lastpage > $finalpage; #not enough pages
    # if near end
    $page = $lastpage - (($maxpages -1) * ${$self->pages}{pagesize})
	if (($page + ($maxpages * ${$self->pages}{pagesize})) > $lastpage);
    $page = 1 if $page < 1;  # not enough pages
    if ($page != 1) {
      push @pages, 1;
      push @pages, '...' unless $page == 1 + ${$self->pages}{pagesize};
      # skip dots for second page start
    }
    while ($page < $lastpage - 1) {
      push @pages, $page;
      $page += ${$self->pages}{pagesize};
    }
    push @pages, '...' #insert if there is at least a single uncovered page
      if $page < $finalpage - ${$self->pages}{pagesize} + 1;
    push @pages, $finalpage;
  }
  return \@pages;
}

sub page_setup {
  my $result = shift;
  cluck ('CWB::Model::Result::pages helper not called with %opts,' . "\n" .
    "please ensure even number of arguments in the form of\n" .
     ' ->pages(startfrom=>3 ...);' . "\n")
       if @_ > 0 and scalar @_ % 2 != 0;
  my %data = @_;

  if (not $data{startfrom} or $data{startfrom} < 1)
    { $data{startfrom} = 1; }     #startfrom may be tainted
  elsif ($data{startfrom} > $result->hitno)
    { $data{startfrom} = $result->hitno - 1 ; }
  else
    { $data{startfrom} = int($data{startfrom}); }

  if ( $data{reduce}
       or $result->hitno <= $data{pagesize} ) {
    ${$result->pages}{single} = 1;
    ${$result->pages}{this} = 1;
  } else {
    my $thispage = $data{startfrom} ? $data{startfrom} : 1;
    my $nextpage = $data{startfrom} + $data{pagesize} <= $result->hitno  - 1 ?
	  $data{startfrom} + $data{pagesize} : undef ;
    ${$result->pages}{this} = $thispage;
    ${$result->pages}{next} = $nextpage;
    ${$result->pages}{prev} = $data{startfrom} - $data{pagesize} >= 1 ?
      $data{startfrom} - $data{pagesize} :
	($thispage == 1 ? undef : 1);
    ${$result->pages}{pagesize} = $data{pagesize};
  }
  return ${$result->pages}{this};
}

# $r->sort( target=>'match', order=>'ascending', direction=>'reversed')
sub sort {
  my $self = shift;

  # check options
  cluck('CWB::Model::Result::sort() called with no sort arguments, skipping') and return unless scalar @_;
  cluck('CWB::Model::Result::sort() called with uneven arguments, skipping') and return
    if ( (scalar @_) % 2);

  my %opts = @_;

  croak('CWB::Model::Result::sort() called with att => ' . $opts{att} . ', which does not exist in the result set') 
    unless join(' ', @{$self->attributes->[0]}) =~ m/$opts{att}/;
  croak('CWB::Model::Result::sort() called with target => ' . $opts{target} . ', which is not a legal target (order, left, match, right)')
    unless $opts{target} =~ m/order|left|match|right/;

  # this could/chould be property
  my $wordlist = 1;
  $wordlist = 0 if ref $self->hits->[0] eq 'HASH';

  croak('CWB::Model::Result::sort() called with att and target => order, which makes no sense')
    if $opts{att} and  $opts{target} eq 'order';
  croak('CWB::Model::Result::sort() called with target => ' . $opts{target} . ' on a wordlist')
    if $opts{target} =~ m{left|right} and $wordlist;
  cluck('CWB::Model::Result::sort() called unknown direction => ' . $opts{direction} . ', ignoring option')
    unless $opts{direction} =~ m/reversed|atergo|normal/;
  cluck('CWB::Model::Result::sort() called unknown order => ' . $opts{order} . ', using default: ascending')
    and $opts{order} = 'ascending'
      unless $opts{order} =~ m/descending|ascending/;
  cluck('CWB::Model::Result::sort() called with target => order and reverse, reverse ignored')
    if $opts{reverse} and $opts{target} eq 'order';

  my $reverse;
  $reverse = 1
    if $opts{direction} eq 'reversed'
      or $opts{direction} eq 'atergo';

  my $att = 0; #defaults to the first att
  if ($opts{att}) {
   $att = _firstidx { $_ eq $opts{att} } @{$self->attributes->[0]};
  }

  my $t = $opts{target};
  my $off = 0;
  $off = -1 if $t eq 'left' and not $reverse;
  $off = -1 if $t ne 'left' and $reverse;

  # hack to only normalize if required; allows repeated sorts
  my $x; $x = 7 unless exists $opts{normalize} and  $opts{normalize};

  # do the sort

  if ($opts{target} eq m{order} and $wordlist) {
    @{$self->hits} =
      sort {
	my $c = ( $a->[1] <=> $b->[1]);
	($c + $x ? $c : ($a->[0][0] cmp $b->[0][0]) );
      } @{$self->hits};
    @{$self->hits} = reverse @{$self->hits}
      if ($opts{order} eq 'descending');
  } elsif ($opts{target} eq m{order} and not $wordlist) {
    @{$self->hits} =
      sort {
	my $c = ( $a->{cpos} <=> $b->{cpos} );
	($c + $x ? $c : ( $a->[0][0] cmp $b->[0][0] ) );
      } @{$self->hits};
    @{$self->hits} = reverse @{$self->hits}
      if ($opts{order} eq 'descending');
  } elsif ($wordlist) {
    @{$self->hits} =
      sort {
	my $c = ($reverse ? reverse $a->[0][$att] : $a->[0][$att]) cmp ($reverse ? reverse $b->[0][$att] : $b->[0][$att]);
	($c + $x ? $c : ($a->[1] <=> $b->[1]) );
      } @{$self->hits};
    @{$self->hits} = reverse @{$self->hits}
      if ($opts{order} eq 'descending');
  } else { #not wordlist, not order
    @{$self->hits} =
      sort {
	my $c = ($reverse ? reverse $a->{$t}[$off][$att] : $a->{$t}[$off][$att]) cmp ($reverse ? reverse $b->{$t}[$off][$att] : $b->{$t}[$off][$att]);
	($c + $x ? $c : ( $a->{cpos} <=> $b->{cpos} ) );
      } @{$self->hits};
    @{$self->hits} = reverse @{$self->hits}
      if ($opts{order} eq 'descending');
  }
}

1;
