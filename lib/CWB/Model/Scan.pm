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
	 rangefile outfile ) ] ;
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
    $keys .= ' ' . ($token->{token} || 'word');
    $keys .= '+' . ($token->{pos} || '0');
    $keys .= '=/' . $self->_mangle_search($token->{query}) . '/'
      . ($token->{case} ?       'c' : '')
      . ($token->{diacritics} ? 'd' : '')
	if $token->{query} and not $token->{query} eq '.*';
  }

  warn "Generated keys: $keys\n" if $self->debug;
  my $scancmd = "cwb-scan-corpus -q -r $registry $opts $corpus $keys";
  warn "Running cwb-scan-corpus with\n $scancmd\n" if $self->debug;

  my $cwbscan = open(my $CS, '-|', $scancmd)
    || warn "Can't run cwb-scan-corpus: $!";
  warn "cwb-scan-corpus failed " and return undef unless $cwbscan;

  warn "Spawned cwb-scan-corpus: pid $cwbscan\n" if $self->debug;

  my @results;
  while (<$CS>) {
    # decode here
    push @results, [ split /\t/, $_ ];
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
  $result->QUERY($keys);
  $result->scantokens($self->tokens);

  $result->hitno(scalar @results);
  @{$result->hits} =  [@results];
# map { [
			    # TODO do something smart with tokens here
			    # such as:
			    # add - for att when missing att in token
			    # add token ..3.. for 3 skipped tokens
#			   ] }
#	@results;
  $result->time(Time::HiRes::gettimeofday() - $query_start_time);

  return $result;
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
