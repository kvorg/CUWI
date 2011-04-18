# Dependencies: Mojolicius, Task::Weaken

package CWB::Model;
use Carp;
use IO::Dir;
use IO::File;
use CWB::Config;

use Mojo::Base -base;

#BUG: registry and corpora can't really work like this at all!
# this only works with ENV currently

has registry => sub {
  return $ENV{CORPUS_REGISTRY} ? $ENV{CORPUS_REGISTRY} : $CWB::Config::Registry;
} ;
has corpora => sub {
  return { } ; 
};

sub new {
  my $self = shift->SUPER::new(@_);

  $self->reload;
  return $self;
}

sub reload {
  my $self = shift;

  # existing virtual corpora cannot be reloaded
  my %virtuals =
    map { ($_ => ${$self->corpora}{$_}) }
      grep
	{ ${$self->corpora}{$_}->isa('CWB::Model::Corpus::Virtual') }
	  keys %{$self->corpora};
#  warn ((scalar keys %virtuals) . " virtual corpora present at reload.\n");

  $self->corpora( {
		map {
		  my $corpus = CWB::Model::Corpus::Filebased->new($_, $self->registry);
		  croak "CWB::Model::Corpus Exception: Could not instantiate Corpus object for $_ "
		    unless $corpus->isa('CWB::Model::Corpus::Filebased');
		  ($corpus->name, $corpus);
		} grep {
		  -f $_  and not ( m{/[#]} or m {[#~]$});
		} map {
		  my $dirname = $_;
		  map { "$dirname/$_" } IO::Dir->new($dirname)->read;
		} split (':', $self->registry)#, %virtuals
	      } ) ;
  ${$self->corpora}{$_}->reload
    foreach keys %virtuals; #reload subcorpora
};

# factory for virtual corpora
sub virtual {
  my $self = shift;
  my $corpus = CWB::Model::Corpus::Virtual->new(@_);
  ${$self->corpora}{$corpus->name} = $corpus;
  return $corpus;
}

our $exception_handler = sub { die @_ ; } ;

sub install_exception_handler {
  my ($this, $handler) = @_;
  return $exception_handler unless $handler;
  if ( $handler and ref $handler eq 'CODE' ) {
    $exception_handler = $handler ;
  } else {
    $exception_handler = sub { die @_ ; } ;
  }
  return $exception_handler;
}

sub dump {
  use Data::Dumper;
  Dumper([ shift->corpora ]);
}

# list names of available corpora
sub list {
  return keys %{shift->corpora};
}

# list names of available corpora with titles
sub list_long {
  my $corpora = shift->corpora;
  return map { ( $_ => $corpora->{$_}->title) } keys %$corpora;
}

package CWB::Model::Corpus;
use Mojo::Base -base;
use Carp qw(croak cluck);

has [qw(name NAME title)];
has [qw(attributes structures alignements)] => sub { return [] };
has [qw(description tooltips)]        => sub { return {} };
has encoding => 'utf8';

sub new {
  my $self = shift;
  croak 'CWB::Model::Corpus error: CWB::Model::Corpus virtual class instantiated - use a specialization.' if ref $self eq 'CWB::Model::Corpus';

  $self->SUPER::new(@_);
}

sub describe {
  croak 'CWB::Model::Corpus syntax error: not called as $corpus->describe(<lang>);' unless @_ == 2;
  return ${shift->description}{shift()};
}

sub tooltip {
  croak 'CWB::Model::Corpus syntax error: not called as $corpus->tooltip(<attribute|structure> => <name>. <lang>);.' unless @_ == 4;
  my ($self, $type, $name, $lang) = @_;
  return ${$self->tooltips}{$type}{$name}{$lang};
}

sub reload {
  cluck 'CWB::Model::Corpus error: this corpus does not implement a ->reload() method.' ;
}

package CWB::Model::Corpus::Filebased;
use Mojo::Base 'CWB::Model::Corpus';
use Carp;

has [qw(file infofile registry)];

sub new {
  my $self = shift->SUPER::new(file => shift, registry => shift);

  $self->name(  $self->file =~ m{.*/([^/]+)$} );
  $self->NAME(uc($self->name));

  my $fh = new IO::File;
  $fh->open($self->file, '<')
    or croak "CWB::Model::Corpus Exception: Could not open $self->file for reading during corpus init.\n";
  while (<$fh>) {
    $self->title($1)               if m/NAME\s+"([^#]*)"/ ;
    $self->infofile($1)            if m/INFO\s+([^# \n]*)/ ;
    push @{$self->alignements}, $1 if m/ALIGNED\s+([^# \n]*)/ ;
    push @{$self->attributes}, $1  if m/ATTRIBUTE\s+([^# \n]*)/ ;
    push @{$self->structures}, $1  if m/STRUCTURE\s+([^# \n]*)/ ;
  }
  $fh->close;
  $self->title( ucfirst($self->name) ) unless $self->title;

  if ($self->infofile and
      $fh->open($self->infofile, '<:encoding(UTF-8)') ) {
    my $lang;
    while (<$fh>) {
      $lang = $1 || 'en'
	and ${$self->description}{$lang} = ''
	  or next if m/^DESCRIPTION\s*([^# \n]*)/;
      ${$self->description}{$lang} .= $_
	if ($lang);
      $self->encoding($1)
	if m/ENCODING\s+([^# \n]*)/ ;
      ${$self->tooltips}{lc($1)}{$2}{$3 ? $3 : 'en'} = $4
	if m/(ATTRIBUTE|STRUCTURE)\s+([^# \n]+)\s+(?:([^# \n]+)\s+)?"([^#]*)"/ ;
    }
    $fh->close;
  } else {
    warn 'Could not access info file for ' . $self->file . ": $@\n";
  }

  $self->encoding('utf8') unless $self->encoding;
  $self->encoding('utf8') if $self->encoding eq 'UTF-8';

  return $self;
}


# change api to reuse query without reopening corpora?
sub query {
  my $self = shift;
  croak 'CWB::Model::Corpus syntax error: not called as $corpus->query(query => <query>, %opts);' unless @_ >= 2 and scalar @_ % 2 == 0;
  return CWB::Model::Query->new(corpus => $self, registry => $self->registry, @_)->run;
}

sub structures_ {
  return [ grep { m/_/ } @{$_[0]->structures} ];
}

package CWB::Model::Corpus::Virtual;
use Mojo::Base 'CWB::Model::Corpus';
use Carp qw(croak cluck);

has subcorpora  => sub { return []; };
has _subcorpora => sub { return {}; };
has qw(interleaved model);

# ->virtual(name=> [ qw(subcorpusname scn scn) ], interleaved=>1)
#   possibly title attributes, structures, description, tooltips
sub new {
  croak "CWB::Model::Corpus::Virtual syntax error: not called as ->new('name'=>[<corpora>], %opts)" unless scalar @_ >= 3 and ((scalar @_) - 1) % 2 == 0;
  my ($this, $name, $subcorpora) = (shift, shift, shift);
  my $self = $this->SUPER::new(name => $name,
			       subcorpora => $subcorpora,
			       @_
			      );
  croak "CWB::Model::Corpus syntax error: virtual corpora should have at least one subcorpus.\n"
    if scalar @{$self->subcorpora} < 1;

  $self->NAME(uc($self->name));
  $self->title( ucfirst($self->name) ) unless $self->title;

  # generate corpora here

  # virtual attributes, structures, alignements: 
  # use superset here and filter when passing to subcorpus
}

sub registry { croak "CWB::Model::Corpus::Virtual syntax error: no registry in virtual corpora.\n" }

sub file { croak "CWB::Model::Corpus::Virtual syntax error: no file in virtual corpora.\n" }


sub reload {
  my $self;
  $CWB::Model::exception_handler->("Could not map subcorpora from model instances - no model passed to virtual coprus.\n") unless $self->model;

  return $self->_subcorpora =
    {
     map {
           $CWB::Model::exception_handler->("Could not map subcorpus $_ from model - missing among model's corpora.\n") unless ${$self->model}{$_};
	   ($_ => ${$self->model}{$_})
	 } @{$self->subcorpora}
    };
}

sub _map_opts {
  my $self = shift;
  my $subcorpus = shift;
  croak 'CWB::Model::Corpus syntax error: not called as $corpus->query(query => <query>, %opts);' unless @_ >= 2 and scalar @_ % 2 == 0;
  # this should map virtual options (atts, structures, aligns) to actual ones
  # and will be called at query time
  return(@_, identify=>1);
}

sub query {
  my $self = shift;
  $CWB::Model::exception_handler->("Query called on a virtual corpus with no subcorpora, aborting.\n") unless scalar @{$self->subcorpora};
  # single subcorpus: virtual corpus mapping
  if (scalar @{$self->subcorpora} == 1) {
    cluck 'CWB::Model::Corpus error: atribute interlieved set on a virtual corpus with a single subcorpus - adding more corpora would help.' if $self->interlieved;
    return ${$self->subcorpora}[0]->query($self->_map_opts(${$self->subcorpora}[0], @_));
  }
  # interleave 0/1support here
  # support in Filecorpus query by hitssonly => 1
  #        (so we can caluclate the ratio based on maxhits here)
  # support in Result by storing subcorpora offsets and ratios
  # query: how to interact?
  #        use hit->data to store real corpus by adding functionality to query
  #        compose hits and tables here (are tables generic?)
  #        we should store ratio per corpora with result to enable paging
  #        and support ratio
  my %opts = @_;

  # multiple corpora: hitnums are needed for paging and interleaved (slow)
  my %hitinfo;
  foreach my $subcorpus (@{$self->subcorpora}) {
    $hitinfo{$subcorpus->name}{hits} = $subcorpus->query($subcorpus, $self->_map_opts(%opts), hitsonly=>1);
  }
  my $result = CWB::Model::Result->new;

  # sequential subcorpora: check into which subcorpus we fall
  # rethink to be more objective and query hits on the fly
  unless ($self->interlaved) {
    my $offset = 0;
    foreach my $subcorpus (@{$self->subcorpora}) {
      $hitinfo{$subcorpus->name}{start} =
	($opts{startfrom} - $offset > 1
	  and $opts{startfrom} - $offset <= $hitinfo{$subcorpus->name}{hits}) ?
	  $opts{startfrom} - $offset : undef;
      $hitinfo{$subcorpus->name}{pagesize} =
	$opts{startfrom} - $offset < 1 ?
	  $opts{pagesize} + $opts{startfrom} - $offset : $opts{pagesize};
      $offset += 0;
    }
  } else {
  # interleaved
    foreach my $subcorpus (@{$self->subcorpora}) {
      # manipulate start and pagesize here for paging and ratii
      my $r = $subcorpus->query($subcorpus, $self->_map_opts(%opts));
      $result->hitno($result->hitno + $r->hitno);
      $result->distinct($result->distinct + $r->distinct);
      push @{$result->hits}, @{$r->hits};
    }
  }
  $result->attributes($opts{show});
  $result->aligns(exists $opts{aligns} ? $opts{aligns} : []);

  # finalize pages

  return $result;
}

package CWB::Model::Query;
use Mojo::Base -base;
use Carp;
use CWB::CQP;
use Encode qw(encode decode);

has [ qw(corpus registry cqp
	query reduce maxhits identify
	l_context r_context debug) ] ;
has search      => 'word';
has show        =>  sub { return [] };
has showstructs =>  sub { return [] };
has align       =>  sub { return [] };
has ignorecase  => 1;
has ignorediacritics => 0;
has startfrom   => 1;
has pagesize    => 25;
has context     => 25;
has display     => 'kwic';
has result      => sub { CWB::Model::Result->new };

sub new {
  use Scalar::Util qw(weaken);
  my $this = shift;
  my %args = @_;
  my $structures;
  if ($args{showstructs}) {
    $structures = $args{showstructs};
    delete $args{showstructs};
  }

  my $self = $this->SUPER::new(%args);
  weaken($self->corpus);  #avoid circular references
  $self->structures(@{$structures}) if $structures;

  # instantiate CQP - but should have more than one in the future
  my $cqp = CWB::CQP->new
    or CWB::Model::exception_handler->('CWB::Model Exception: Could not instantiate CWB::CQP.');
  # set registry - needed since we can supercede the ENV and CWB::Config
  $cqp->exec("set registry '" . $self->registry . "';");
  return $CWB::Model::exception_handler->('CWB::Model Exception: can\'t open registry. -', $cqp->error_message)
    unless $cqp->ok;
  # activate corpus
  $cqp->exec($self->corpus->NAME . ';');
  # enable corpus position and timing
  $cqp->exec("show +cpos");
  return $CWB::Model::exception_handler->('CWB::Model Exception: can\'t set +cpos. -', $cqp->error_message)
    unless $cqp->ok;
  $cqp->exec("set Timing on");
  return $CWB::Model::exception_handler->('CWB::Model Exception: can\'t enable timing display. -', $cqp->error_message)
    unless $cqp->ok;
  # set easy-to-parse left and right match delimiters
  $cqp->exec("set ld '::--:: ';");
  return $CWB::Model::exception_handler->('CWB::Model Exception: can\'t set ld. -', $cqp->error_message)
    unless $cqp->ok;
  $cqp->exec("set rd ' ::--::';");
  return $CWB::Model::exception_handler->('CWB::Model Exception: can\'t set rd. -', $cqp->error_message)
    unless $cqp->ok;
  $self->cqp($cqp);

  return $self;
}

sub run {
  use Time::HiRes;
  my $self = shift;
  $self->exception("No queriable corpus passed to CWB::Model::Query: aborting run. ")
    and return
      unless ref $self->corpus and $self->corpus->isa('CWB::Model::Corpus::Filebased');

  my $query_start_time = Time::HiRes::gettimeofday();

  my $query = $self->query;
  if ( $query =~ m{^\s*[~=]}
       or (not $query =~ m{"} and not $query =~ m{^\s*[+]}) ) {
    # simple or mixed query - transform into CQP query
    $query =~ s{^\s*}{};           #remove leading white space
    my $qtype = 'mixed';
    $query =~ s{^~\s*}{};
    $qtype = 'simple' if $query =~ s{^=\s*}{};

    $query = join(' ',
		   map {
		     if ( $qtype eq 'simple' ) {
		       s/[*]/\\*/g;
		       s/[?]/\\?/g;
		       s/(\[|\])/\\$1/g;
		       s/"/""/gm;
		     } elsif (not m{^\[}) {
		       s/(?<!\\)[*]/.*/g;
		       s/(?<!\\)[?]/./g;
		       s/(\[|\])/\\$1/g;
		     }
		     (m{^\[}) ? $_ :
		   '['
		     . (defined $self->search ?
			$self->search : 'word')
		       . '="' . $_ . '"'
		       . ( ( $self->ignorecase or $self->ignorediacritics ) ? ' %' : '' )
		       . ( $self->ignorecase ? 'c' : '' )
		       . ( $self->ignorediacritics  ? 'd' : '' )
		      . ']'
		     } split('\s+', $query)
		  );
    warn("Passing query as $query.\n") if $self->debug;
  } else { #handle CQP escape
    $query =~ s{^\s*[+]?\s*}{};
  }

  # test CQP connection
  $self->exec("show", 'CQP not answering');

  # reset CQP settings
  foreach my $att (@{$self->corpus->attributes}) {
    $self->exec("show -$att;", "Can't unset show for attribute $att");
  }

  foreach my $align (@{$self->corpus->alignements}) {
    $self->exec("show -$align;", "Can't unset show for alignement $align");
  }

  # set new CQP settings
  foreach my $att (@{$self->show}) {
    $self->exec("show +$att;", "Can't set show for attribute $att");
  }

  my @aligns = grep { my $align = $_;
		      scalar grep { $_ eq $align }
			@{$self->corpus->alignements}
		      } @{$self->align} ;

  unless ($self->display eq 'wordlist') { # no alignment for wordlists
    foreach my $align (@aligns) {
      $self->exec("show +$align;", "Can't set show for alignement $align")
    }
  }

  if ($self->display ne 'wordlist') {
    $self->exec('set Context ' . $self->context . ';',
		"Can't set context to '" . $self->context . "'")
      if defined $self->context;
    $self->exec('set LeftContext ' . $self->l_context . ';',
		"Can't set left context to '" . $self->l_context . "'")
      if defined $self->l_context;
    $self->exec('set RightContext ' . $self->r_context . ';',
		"Can't set right context to '" . $self->r_context . "'")
      if defined $self->r_context;
  my $ps = join(', ', @{$self->corpus->structures});
  $self->exec('set PrintStructures "' . $ps . '";',
	      "Can't set PrintStructures for");
  } else {
    $self->exec('set Context 0;',
		"Can't set context to '" . $self->context . "'");
    $self->exec('set PrintStructures ""', "Can't set PrintStructures.");
  }

  $self->exec('set Context s;', "Can't set context to 's''")
    if $self->display eq 'sentences';
  $self->exec('set Context p;', "Can't set context to 'p''")
    if $self->display eq 'paragraphs';
  $self->exec('set Context 0 words;', "Can't set context to 'p''")
    if $self->display eq 'wordlist';

  # execute query (but don't show the results yet)
  my $_query = encode($self->corpus->encoding, $query);
  $self->cqp->exec_query($_query); # for tainted execution
  $self->exception("CQP query for $query failed -",
		   $self->cqp->error_message)
    unless $self->cqp->ok;

  # process results into a result object
  my $result = CWB::Model::Result->new(corpusname => $self->corpus->name)
    or $self->exception("Failed to create a result object.");

  $result->query($query);
  $result->QUERY($_query);
  @{$result->attributes} = $self->show;
  @{$result->aligns} = @aligns;
  $result->hitno($self->cqp->exec("size Last"));

  # select context display type for hit context presentation
  $result->bigcontext('paragraphs') if grep { $_ } map { $_ eq 'p' }
    @{$self->corpus->structures};
  $result->bigcontext('sentences') if not $result->bigcontext
    and grep { $_ } map { $_ eq 's' }
    @{$self->corpus->structures};

  # sort here

  # reduce?
  if ($self->display eq 'kwic'
      or $self->display eq 'sentences'
      or $self->display eq 'paragraphs') {
    if ($self->reduce and $self->pagesize) {
      $self->exec("reduce Last to " . $self->pagesize);
      $result->reduce(1);
    }

    # compute page list for navigation
    my $pages = '';

    if ($self->startfrom < 1)
      { $self->startfrom(1); }     #startfrom may be tainted
    elsif ($self->startfrom > $result->hitno)
      { $self->startfrom($result->hitno - 1) ; }
    else
      { $self->startfrom(int($self->startfrom)); }

    if ( $self->reduce 
	 or $result->hitno <= $self->pagesize ) {
      ${$result->pages}{single} = 1;
    } else {
      my $thispage = $self->startfrom ? $self->startfrom : 1;
      my $nextpage = $self->startfrom + $self->pagesize <= $result->hitno  - 1?
	$self->startfrom + $self->pagesize : undef ;
      ${$result->pages}{this} = $thispage;
      ${$result->pages}{next} = $nextpage;
      ${$result->pages}{prev} = $self->startfrom - $self->pagesize >= 1 ?
	$self->startfrom - $self->pagesize : 
	  ($thispage == 1 ? undef : 1);
      ${$result->pages}{pagesize} = $self->pagesize;
      $pages = $thispage . ' ' . ($nextpage ? $nextpage - 1 : $result->hitno)
	if $self->pagesize and not $self->reduce;
    }

    my @kwic = $self->cqp->exec("cat Last $pages");

    foreach my $kwic (@kwic) {
      if ($kwic =~ m{^-->(.*?):\s(.*)$}) { #align - to previous hit
	$self->exception("Found an aligned line without a previous hit:", $kwic)
	  and next
	    unless (scalar @{$result->hits});
	${@{$result->hits}[-1]}{aligns}{$1} = decode($self->corpus->encoding, $2);
      } else { #kwic
	$kwic =~ m{^\s*([\d]+):        # cpos
		   (?:\s+<(.*)>:)?\s+  # structs
		   (.*?)               # left
		   \s*::--::\s+        # separator
		   (.*?)               # match
		   \s+::--::\s*        # separator
		   (.*?)               # right
		   \s*$}x              # tail
	  or $self->exception("Can't parse CQP kwic output, line:", $kwic);
	my ($cpos, $structs, $left, $match, $right) =
	  (
	   $1,
	   $2,
	   decode($self->corpus->encoding, $3),
	   decode($self->corpus->encoding, $4),
	   decode($self->corpus->encoding, $5),
	  );

	my $data = {};
	if ($structs) {
	  foreach (split '><', $structs) {
	    m{(\S*)\s(.*)};
	    $data->{$1} = $2;
	  }
	}

	push @{$result->hits}, {
				cpos    => $cpos,
				left    => $left,
				match   => $match,
				right   => $right,
				data    => $data,
			       aligns  => {},
			       };
      }
    }
    #manual sort here

  } elsif ( $self->display eq 'wordlist' ) {
    ${$result->pages}{single} = 1;
    if ($self->reduce and $self->pagesize) {
      $result->reduce(1);
    }
    $result->table(1);
    my @kwic = $self->cqp->exec("cat Last 1 10000"); # limit max
    warn "Got " . scalar @kwic . " lines.\n";
    my %counts;
    foreach my $kwic (@kwic) {
      $kwic =~ m{::--:: (.*) ::--::}
	or $self->exception("Can't parse CQP kwic output for wordlist, line:", $kwic);
      my $match = decode($self->corpus->encoding, $1);
      $match = lc($match) if $self->ignorecase;
      $counts{$match} = 0 unless exists $counts{$match};
      $counts{$match}++ ;
    }
    @{$result->hits} = map { [$_, $counts{$_}] }
      reverse sort {$counts{$a} <=> $counts{$b}}  keys %counts;
    # reduce only shows the top frequencies for wordlists
    splice @{$result->hits}, $self->pagesize
      if $self->reduce and $self->pagesize > 0;
    $result->distinct(scalar keys %counts);
  } else {
    $self->exception("No known display mode specified, aborting query.");
  }

  $result->time(Time::HiRes::gettimeofday() - $query_start_time);
  return $result;
}

sub exec {
  my ($self, $command, $error) = @_;
  $self->cqp->exec($command);
  $self->exception("$error -", $self->cqp->error_message)
    unless $self->cqp->ok;
}

sub exception {
  shift;
  return $CWB::Model::exception_handler->('CWB::Model Exception: ' . shift, @_);
}

package CWB::Model::Result;
use Mojo::Base -base;

has [qw(query QUERY time distinct next prev reduce table bigcontext corpusname)] ;
has hitno       => 0;
has hits        => sub { return [] } ;
has pages       => sub { return {} } ;
has attributes  => sub { return [] } ;
has aligns      => sub { return [] } ;

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
    $page = ${$self->pages}{this}
      - int($maxpages / 2) * ${$self->pages}{pagesize};
    # if near beginning
    $page = 1 if $page < 1;
    # if near end
    $page = $self->hitno - $maxpages * ${$self->pages}{pagesize} + 1
      if $page + $maxpages * ${$self->pages}{pagesize} > $self->hitno;
    $page = 1 if $page < 1;  #not enough pages
    my $lastpage  = $page + $maxpages * ${$self->pages}{pagesize};
    my $finalpage = $self->hitno - 
      ($self->hitno ? 1 : $self->hitno % ${$self->pages}{pagesize});
    $lastpage = $self->hitno
      if $lastpage > $self->hitno; #not enough pages
    push @pages, 1, '...' if $page != 1;
    while ($page < $lastpage - 1) {
      push @pages, $page;
      $page += ${$self->pages}{pagesize};
      push @pages, '...', $finalpage if $page > $lastpage - 1 and $page < $self->hitno -1;
    }
  }
  return \@pages;
}

1;

=head1 NAME

CWB::Model - CWB registry, corpus, info and query model layer

=head1 SYNOPSIS


  $model = CWB::Model->new;       # instantiate a model
  $mine  = CWB::Model->new( "$ENV{HOME}/corpora/registry" );
  
  
  print join(', ', $model->list);  # list corpora names
  %corpora = $model->list_long     # corpora names and titles:
  $corpora = $model->corpora       # all corpora (as CWB::Model::Corpus)
  my $corpus  = $corpora->[0];     # first corpus
  my $dickens = ${$model->corpora}{dickens};        # specific corpus
  my $text    = $corpus->encoding; # corpus encoding from info file
  my $en_desc = $corpus->describe('en');            # English description
  $corpus->tooltip(attribute => 'pos', 'en');        # English tooltips
  $corpus->tooltip(structure => 'doc', 'en')
  
  # run a query (see CWB::Model::Query for options)
  
  my $result  = $model>corpora('dickens')->query(query =>'...', %options);
  my $thesame = $dickens->query(query =>'...', %options);
  
  # inspect the result set
  
  $result->query (CQP query with no paging)
  $result->QUERY (actual generated CQP query)
  $result->time  (time to run the query in ms)
  $result->hitno  (no of hits)
  foreach ($result->hits) { display UTF structures ... }

=head1 DESCRIPTION

CWB::Model is a data model for querying CWB corpus collections.  A
CWB:Model exports a catalog of corpus information as found in the
supplied registries in the form of L<CWB::Model::Corpus>, objects,
runs C<cqp> queries on them using L<CWB::CQP> via L<CWB::Model::Query>
and presents results as L<CWB::Model::Results>.

=head2 QUERIES

Queries can be specified in the C<CQP> syntax or as simple queries
using C<*> and C<?> meta characters. Simple queries use options, such
as C<< ignorecase => 1 >> or C<< search => 'pos' >> to transform
simple queries into full C<CQP> query format.

Input and output is strictly in C<UTF-8>. (Info files are used for
encoding specification at this time, upcoming CWB standard in the next
UTF-8 capable release will be used as available.)

Note that queries using regular expressions will likely fail or
produce unexpected results with L<UTF-8> unless supported at the
L<CWB> backend.

=head2 IMPLEMENTATION NOTES

CWB libraries are only accessed for queries, not corpus introspection,
which is handled by file inspection at object instantiation. Corpus
objects will cache query objects and C<CQP> instances for better
performance. Note that this is not the same as actual cacheing of
queries, as done by Stefan Evert's L<CWB::Web::Cache>. If actual
results need to be cached, for example in a web-service scenario,
consider a RESTful intefrace and a front-end web cache
(i.e. Varnish). See included L<cqp> web query tool for and example.

Errors, inclucing L<CWB::CQP> errors, are thown as C<die()> exceptions
capturable as C<CWB::Model Exception> unless an exception handler is
set. See L</EXCEPTIONS>.


=head1 METHODS


=head1 ATTRIBUTES

# defaults to the CORPUS_REGISTR environemnt variable
# or /usr/local/share/cwb/registry:/usr/local/cwb/registry

=head1 EXCEPTIONS

Errors, inclucing L<CWB::CQP> errors, are thown as C<die()> exceptions
starting with the string C<CWB::Model Exception>. You can capture them
by wrapping any calls to the model in eval or using a suitable module
from C<CPAN>.

L<CWB::Model> also lets you set an exception handler:

  CWB::Model->install_exception_handler( sub { process(@_), somehow; } );

Exception handlers are global to the module and honored by all the
subclasses. The are most useful while dealing with L<CQP> errors.

Note that exception handlers are not called for syntax errors and
similar erros, but L<carp> is used instead.

=head1 INFO FILE EXTENSIONS

=head1 AUTHORS

Jan Jona Javoršek (jan.javorsek@ijs.si),
Tomaž Erjavec (tomaz.erjavec@ijs.si)

Ideas, solutions and even code snippets have been "borrowed" from CWB
module by Stefan Evert [http::/purl.org/stefan.evert].

=head1 LICENCE

This perl package is distributed under the same conditions as perl
itself (Dual Artistic / GPL licence.) See
L<http://dev.perl.org/licenses/> for more info.

Contributors: please note that by contributing to this package you
implicitly agree and give permission to the package maintainer (Jan
Jona Javoršek) to relicence your contributions with the whole package
under a different OSI-Approved licence. See
L<http://www.opensource.org/licenses/> for more info.

=head1 SEE ALSO

L<CWB::CQP>, L<http://...> for L<CQP> syntax and general
B<Corpus WorkBench> information.

=cut

