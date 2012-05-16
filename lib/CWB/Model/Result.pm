package CWB::Model::Result;

use Mojo::Base -base;
use Carp qw(croak cluck);

has [qw(query QUERY time distinct cpos next prev reduce table bigcontext corpusname)] ;
has hitno => 0;
has pages => sub { return {} } ;
has [qw(hits attributes aligns peers)]  => sub { return [] } ;

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

1;
__END__
# $r->sort( target=>'match', order=>'ascending', direction=>'reversed')
sub sort {
    my $self = shift;
    cluck('CWB::Model::Result::sort() called with no sort arguments, skipping') and return unless scalar @_;
    cluck('CWB::Model::Result::sort() called with uneven arguments, skipping') and return
	if scalar @_ % 2;
    my %opts = @_;
      if ($opts{target} =~ m{match}) {
	my $reverse;
	$reverse = 1 if $opts{direction} eq 'reversed';
	if ($opts{order} eq 'descending') {
	  @{$result->hits} = map { [
				    $counts{$_}{value},
				    $counts{$_}{count}
				   ] }
	    sort {
	      my $c = ($reverse ? reverse $b : $b) cmp ($reverse ? reverse $a : $a);
	      ($c ? $c : ($counts{$b}{count} <=> $counts{$a}{count}) );
	    }  keys %counts;
	} else {
	  @{$result->hits} = map { [
				    $counts{$_}{value},
				    $counts{$_}{count}
				   ] }
	    reverse sort {
	      my $c = ($reverse ? reverse $b : $b) cmp ($reverse ? reverse $a : $a);
	      ($c ? $c : ($counts{$b}{count} <=> $counts{$a}{count}) );
	    }  keys %counts;
	}
      } else {
	@{$result->hits} = map { [
				$counts{$_}{value},
				$counts{$_}{count}
			       ] }
	reverse sort {
	  my $c = ($counts{$a}{count} <=> $counts{$b}{count});
	  $c ? $c : ($b cmp $a )
	}  keys %counts;
      }
    } else { #subcorpus query does not sort (saves time)
      @{$result->hits} = map { [
				$counts{$_}{value},
				$counts{$_}{count},
			       	$counts{$_}{data},
			       ] }
	keys %counts;
    }

}

1;
