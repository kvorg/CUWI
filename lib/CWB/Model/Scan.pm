package CWB::Model::Scan;
use Mojo::Base -base;

use CWB::Model;
use CWB::Model::Result;
use CWB::Model::Query;

use Carp;
use Encode qw(encode decode);
use Scalar::Util qw(weaken);
use Time::HiRes;
use POSIX qw(locale_h);

has [ qw(corpus model tokens debug from to freqlimit
	 rangefile outfile subcorpus ) ] ;
has sort        =>  sub { return {} };
has ignorecase  => 1;
has ignorediacritics => 0;
has ignoremeta  => 0;
has maxhits     => 20000;
has result      => sub { CWB::Model::Result->new };

# implement region searches for structural attributes using -s and -e

# consider automatically computing  a suitable bucket number

sub new {
  my $this = shift;
  my %args = @_;

  my $self = $this->SUPER::new(%args);
  weaken($self->corpus);  #avoid circular references
  weaken($self->model);

  # check consistency (atts exist, scanstop in range)
  # check rangefile
  # check outfile dir
  return $self;
}

sub run {
  my $self = shift;
  my $query_start_time = Time::HiRes::gettimeofday();

  warn "CWB::Model::Scan::run() called.\n" if $self->debug;

  my $opts = ' -q'; #consider handling progress
  $opts .= ' -f' . $self->freqlimit if $self->freqlimit;
  $opts .= ' -s' . $self->from if $self->from;
  $opts .= ' -e' . $self->to if $self->to;
  my $registry = $self->model->registry;
  my $corpus   = $self->corpus->NAME;
  my $encoding = $self->corpus->encoding;

  # handle rangefile
  # handle outfile

  # TODO generate keys,  and structural constrains
  my $keys;
  foreach my $token (@{$self->tokens}) {
    # handle ?
    next unless $token->{query};
    $token->{query} =~ s/^\s*(.*?)\s*$/$1/;
    $keys .= ' ' . ($token->{token} || 'word');
    $keys .= '+' . ($token->{pos} || '0'); #TODO: allow natural order for API?
    $keys .= '=/' . $self->_mangle_search($token->{query}) . '/'
      . ($token->{case} ?       'c' : '')
      . ($token->{diacritics} ? 'd' : '')
	if $token->{query} 
	  and not ($token->{query} eq '*' or $token->{query} eq '".*"');
  }

  warn "Generated keys: $keys\n" if $self->debug;
  my $_keys = encode($self->corpus->encoding, $keys);

  my $scancmd = "cwb-scan-corpus -q -r $registry $opts $corpus $_keys";
  warn "Running cwb-scan-corpus with\n $scancmd\n" if $self->debug;

  my $cwbscan = open(my $CS, '-|', $scancmd)
    || warn "Can't run cwb-scan-corpus: $!";
  warn "cwb-scan-corpus failed " and return undef unless $cwbscan;

  warn "Spawned cwb-scan-corpus: pid $cwbscan\n" if $self->debug;

  my @results;
  while (<$CS>) {
    chomp;
    push @results, [ split /\t/, decode($self->corpus->encoding, $_) ];
  }

  warn "cwb-scan-corpus returned " . scalar @results . " results\n"
    if $self->debug;

  # TODO: implement collocation processing here

  # process results into a result object
  my $result =
    CWB::Model::Result->new(corpusname => $self->corpus->name,
			    language => $self->corpus->language || 'en_US')
    or $self->exception("Failed to create a result object.");

  $result->query($keys);
  $result->QUERY($_keys);
  $result->scantokens($self->tokens);
  ${$result->pages}{single} = 1;
  ${$result->pages}{this} = 1;

  $result->distinct(scalar @results);

  my %atts = map { $_->{token} => 1 } grep { $_->{query} } @{$self->tokens};
  my @atts = grep { exists $atts{$_} } @{$self->corpus->attributes};
  my $i = 0;
  my %attpos = map { $_ => $i++ } @atts;
  my @tokens = grep { $_->{query} and not $_->{ignore} } @{$self->tokens};
  my $matches = 0;

  @{$result->hits} =
    map { $matches += $_->[0]; $self->_tuple($_, \%attpos, \@tokens) }
      @results;
  $result->hitno($matches);

  #sorting: subcorpus query does not sort (saves time)
  if ( not $self->subcorpus ) {
    if ($self->sort and exists ${$self->sort}{a} and ${$self->sort}{a}{target} =~ m{match|order} ) {
      $result->sort(%{${$self->sort}{a}});
    } else {
      $result->sort(target=>'order', normalize=>1, order=>'descending');
    }
  }

  $result->time(Time::HiRes::gettimeofday() - $query_start_time);

  return $result;
}

sub _tuple {
    my ($self, $tuple, $attpos, $tokens) = @_;
    my $match = [];
    $DB::single = 2;
    # add * for att when missing att in token
    # add token ..3.. for 3 skipped tokens
    my $freq = shift @$tuple;
    for (my $i = 0; $i < $#{$tuple}+1; $i++) {
      $match->[$tokens->[$i]->{pos}][$attpos->{$tokens->[$i]->{token}}] =
	$tuple->[$i];
    }
    my $skip = 0; my $s = scalar keys %$attpos;
    foreach my $m (@$match) {
      my $full = 0;
      for (my $i = $s - 1 ; $i >= 0 ; $i--) {
	if ($m->[$i]) { $full = 1 } else { $m->[$i] = '*' }
      }
      if ($full) { $skip = 0 } else {
      	if ($skip) { $m = [] } else { $m = [ '...' ]; }
      	$skip++;
      }
    }
    return [ $match, $freq ];
}

sub _mangle_search {
  return $_[1] if substr($_[1], 0, 1) eq '"';
  my ($self, $search) = @_;
  $search =~ s/(?<!\\)[*]/.*/g;
  $search =~ s/(?<!\\)[?]/./g;
  $search =~ s/(\[|\])/\\$1/g;
  return $search;
}

1;
