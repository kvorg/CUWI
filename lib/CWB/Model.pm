# Dependencies: Mojolicius, Task::Weaken

package CWB::Model;
use Carp;
use IO::Dir;
use IO::File;
use CWB::Config;
use utf8;

use Mojo::Base -base;

our $VERSION = '0.9';

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
  use Carp qw(croak);
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
		  my $corpus = CWB::Model::Corpus::Filebased->new($_, $self);
		  croak "CWB::Model::Corpus Exception: Could not instantiate Corpus object for $_ "
		    unless $corpus->isa('CWB::Model::Corpus::Filebased');
		  ($corpus->name, $corpus);
		} grep {
		  -f $_  and not ( m{/[#]} or m {[#~]$});
		} map {
		  my $dirname = $_;
		  croak "Can't open registry $dirname, bailing out.\n"
		    unless -r $dirname and -d $dirname and -x $dirname;
		  map { "$dirname/$_" } IO::Dir->new($dirname)->read;
		} split (':', $self->registry)#, %virtuals
	      } ) ;
  ${$self->corpora}{$_}->reload
    foreach keys %virtuals; #reload subcorpora
};

# factory for virtual corpora
sub virtual {
  my $self = shift;
  my $name = shift;

  croak "CWB::Model Exception: Could not instantiate CWB::Model::Corpus::Virtual $name: name exists in the model."
    and return undef
      if exists ${$self->corpora}{$name};

  my $corpus = CWB::Model::Corpus::Virtual->new(model => $self, $name => @_);
  croak "CWB::Model Exception: Could not instantiate CWB::Model::Corpus::Virtual $name: object instantiation failed." unless defined $corpus and ref $corpus and $corpus->can('subcorpora');
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

our $VERSION = '0.9';

has [qw(name NAME title model)];
has [qw(attributes structures alignements peers)] => sub { return [] };
has [qw(description tooltips stats)]              => sub { return {} };
has encoding => 'utf8';
has Encoding => 'UTF-8';
has language => 'en_US';

sub new {
  use Scalar::Util qw(weaken);
  my $self = shift;
  croak 'CWB::Model::Corpus error: CWB::Model::Corpus virtual class instantiated - use a specialization.' if ref $self eq 'CWB::Model::Corpus';

  $self = $self->SUPER::new(@_);
  weaken($self->model);  #avoid circular references
  return $self;
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

our $VERSION = '0.9';

has [qw(file infofile)];

sub new {
  my $self = shift->SUPER::new(file => shift, model => shift);

  $self->name(  $self->file =~ m{.*/([^/]+)$} );
  $self->NAME(uc($self->name));

  my $fh = new IO::File;
  $fh->open($self->file, '<:encoding(UTF-8)')
    or croak "CWB::Model::Corpus Exception: Could not open $self->file for reading during corpus init.\n";
  while (<$fh>) {
    $self->title($1)               if m/NAME\s+"([^#]*)"/ ;
    $self->infofile($1)            if m/INFO\s+([^# \n]*)/ ;
    push @{$self->alignements}, $1 if m/ALIGNED\s+([^# \n]*)/ ;
    push @{$self->attributes}, $1  if m/ATTRIBUTE\s+([^# \n]*)/ ;
    push @{$self->structures}, $1  if m/STRUCTURE\s+([^# \n]*)/ ;
    $self->encoding($1)            if m/^##::\s*charset\s+=\s+"?[^"#\n]+"?/ ;
    $self->language($1)            if m/^##::\s*language\s+=\s+"?[^"#\n]+"?/ ;
  }
  $fh->close;
  $self->title( ucfirst($self->name) ) unless $self->title;
  push @{$self->attributes}, 'word'
    unless grep { $_ eq 'word' } @{$self->attributes};


  if ($self->infofile and
      $fh->open($self->infofile, '<:encoding(UTF-8)') ) {
    my $lang;
    while (<$fh>) {
      $lang = $1 || 'en'
	and ${$self->description}{$lang} = ''
	  or next if m/^DESCRIPTION\s*([^# \n]*)/;
      ${$self->description}{$lang} .= $_
	if ($lang);
      push @{$self->peers}, $1  if m/PEER\s+([^# \n]*)/ ;
      $self->encoding($1)
	if m/ENCODING\s+([^# \n]*)/ ; #this should go away
      ${$self->tooltips}{lc($1)}{$2}{$3 ? $3 : 'en'} = $4
	if m/(ATTRIBUTE|STRUCTURE)\s+([^# \n]+)\s+(?:([^# \n]+)\s+)?"([^#]*)"/ ;
    }
    $fh->close;
  } else {
    #warn 'Could not access info file for ' . $self->file . ": $@\n";
  }

  $self->encoding('utf8')  unless $self->encoding;
  $self->Encoding($self->encoding) ;
  $self->encoding('utf8')  if $self->encoding eq 'UTF-8';
  $self->Encoding('UTF-8') if $self->encoding eq 'utf8';

  my $cwb_describe = 'cwb-describe-corpus -s -r '
    . $self->model->registry . ' '
    . $self->NAME ;
  my $description = `$cwb_describe`;
  if ($description) {
      ${$self->stats}{attributes} = [];
      ${$self->stats}{structures} = [];
      ${$self->stats}{alignements} = [];

    my @description = split(/^/, $description);
    foreach (@description) {
      ${$self->stats}{tokens} = $1 if m/size\s+.tokens.:\s+(\d+)/;
      push @{${$self->stats}{attributes}}, [ $1, $2, $3 ]
	if m/p-ATT\s+(\w+)\s+(\d+)\s+tokens,\s+(\d+)/;
      push @{${$self->stats}{structures}}, [ $1, $2 ]
	if m/s-ATT\s+(\w+)\s+(\d+)/;
      push @{${$self->stats}{alignements}}, [ $1, $2 ]
	if m/a-ATT\s+([^ \t]+)\s+(\d+)/;
    }
  }

  return $self;
}

sub registry { shift->model->registry };

# change api to reuse query without reopening corpora?
sub query {
  my $self = shift;
  $DB::single = 2;
  croak 'CWB::Model::Corpus syntax error: not called as $corpus->query(query => <query>, %opts);' unless @_ >= 2 and scalar @_ % 2 == 0;
  return CWB::Model::Query->new(corpus => $self, model => $self->model, @_)->run;
}

sub structures_ {
  return [ grep { m/_/ } @{$_[0]->structures} ];
}

package CWB::Model::Corpus::Virtual;
use Mojo::Base 'CWB::Model::Corpus';
use Carp qw(croak cluck);

our $VERSION = '0.9';

has subcorpora  => sub { return []; };
has _subcorpora => sub { return {}; };
has classes => sub { return {}; };
has classnames => sub { return []; };
has [qw(model interleaved general_align)];
has propagate => 'superset';

# ->virtual(name=> [ qw(subcorpusname scn scn) ], interleaved=>1)
#   possibly title peers
#   attributes, structures, description, tooltips
sub new {
  my $this = shift;
  croak "CWB::Model::Corpus::Virtual syntax error: not called as ->new(model => <model>, 'name' => [<corpora>], %opts)" unless scalar @_ >= 3 and $_[0] eq 'model' and ((scalar @_) % 2) == 0;
  shift; my $model = shift;
  my ($name, $subcorpora) = (shift, shift);
  my $self = $this->SUPER::new(name => $name,
			       model => $model,
			       subcorpora => $subcorpora,
			       @_
			      );
  croak "CWB::Model::Corpus syntax error: virtual corpora should have at least one subcorpus.\n"
    if scalar @{$self->subcorpora} < 1;

  $self->NAME(uc($self->name));
  $self->title( ucfirst($self->name) ) unless $self->title;
  $self->Encoding($self->encoding) ;
  $self->encoding('utf8')  if $self->encoding eq 'UTF-8';
  $self->Encoding('UTF-8') if $self->encoding eq 'utf8';

  # generate corpora here
  if ($self->classes and not $self->classnames) {
    @{$self->classnames} = sort keys %{$self->classes};
  }

  # virtual attributes, structures, alignements:
  # use superset here and filter when passing to subcorpus
  #   unless overruled in the specification

  $self->reload;
}

sub registry { croak "CWB::Model::Corpus::Virtual syntax error: no registry in virtual corpora.\n" }

sub file { croak "CWB::Model::Corpus::Virtual syntax error: no file in virtual corpora.\n" }

sub reload {
  my $self = shift;
  $CWB::Model::exception_handler->("Could not map subcorpora from model instances - no model passed to virtual coprus.\n") unless $self->model;

  $self->_subcorpora(
    {
     map {
           $CWB::Model::exception_handler->("Could not map subcorpus $_ from model - missing among model's corpora.\n") unless ${$self->model->corpora}{$_};
	   ($_ => ${$self->model->corpora}{$_})
	 } @{$self->subcorpora}
    }
			   );

  if ($self->propagate) {
    # property propagation
    my %attributes = ();  my @attributes;
    my %structures = ();  my @structures;
    my %alignements = (); my @alignements;
    foreach my $subname (@{$self->subcorpora}) {
      my $subcorpus = ${$self->_subcorpora}{$subname};
      foreach (@{$subcorpus->attributes}) {
	$attributes{$_}++;
	push @attributes, $_ if $attributes{$_} == 1;
      }
      foreach (@{$subcorpus->structures}) {
	$structures{$_}++;
	push @structures, $_ if $structures{$_} == 1;
      }
      foreach (@{$subcorpus->alignements}) {
	$alignements{$_}++;
	push @alignements, $_ if $alignements{$_} == 1;
      }
    }
    if ($self->propagate eq 'superset') {
      @{$self->attributes} = @attributes;
      @{$self->structures} = @structures;
      @{$self->alignements} = @alignements;
    } else { #subset
      my $scn = scalar @{$self->corpra};
      foreach (@attributes) {
	push @{$self->attributes}, $_ if $attributes{$_} = $scn;
      }
      foreach (@structures) {
	push @{$self->structures}, $_ if $structures{$_} = $scn;
      }
      foreach (@alignements) { #probably makes no sense
	push @{$self->alignements}, $_ if $alignements{$_} = $scn;
      }
    }

    #tooltips
    my $propagate_level;
    $propagate_level = sub {
      my ($target, $source) = @_;
      foreach (keys %$source) {
	next if exists $target->{$_};
	if (ref $source->{$_} eq 'HASH') {
	  $target->{$_} = {};
	  $propagate_level->($target->{$_}, $source->{$_});
	} else {
	  $target->{$_} = $source->{$_};
	}
      }
    };

    foreach my $subname (@{$self->subcorpora}) {
      my $subcorpus = ${$self->_subcorpora}{$subname};
      $propagate_level->($self->tooltips, $subcorpus->tooltips)
    }

  }

  return $self;
}

sub _make_result {
    my $self = shift;
    my %opts = @_;

    my $result = CWB::Model::Result->new(corpusname => $self->name)
      or $self->exception("Failed to create a result object.");

    @{$result->attributes} = [];
    @{$result->peers} = $self->peers;
    $result->hitno(0);
    $result->distinct(0);

    # select context display type for hit context presentation - obsoleted?
    #$result->bigcontext($bigcontext);

    # hitsonly
    #if ($self->hitsonly) {
    #  $result->time(Time::HiRes::gettimeofday() - $query_start_time);
    #  return $result;
    #}
    return $result;
}


sub _map_opts {
  my $self = shift;
  my $subcorpus = shift;
  my $opts = shift;
  my %buts = @_;
  my %opts;

  cluck 'CWB::Model::Corpus::Virtual syntax error: not called as $corpus->query(query => <query>, \%opts, [%buts]) in subquery ops processing;' if @_ > 0 and scalar @_ % 2 != 0;
  # this should map virtual options (atts, structures, aligns) to actual ones,
  # allow for call time overrides
  # and will be called (multiple times) at query time
  foreach (keys %$opts) {
    $opts{$_} = (exists $buts{$_} ? $buts{$_} : $opts->{$_});
  }
  $DB::single = 2;
  return(%opts);
}

sub query {
  use Time::HiRes;
  my $query_start_time = Time::HiRes::gettimeofday();

  my $self = shift;
  $CWB::Model::exception_handler->("Query called on a virtual corpus with no subcorpora, aborting.\n") unless scalar @{$self->subcorpora};

  my %opts = @_;
  $opts{startfrom} ||= 0;
  $opts{align} = $self->alignements
    if ($opts{align} and $self->general_align);

  # single subcorpus: virtual corpus mapping
  if (scalar @{$self->subcorpora} == 1) {
    croak 'CWB::Model::Corpus error: atribute interlieved set on a virtual corpus with a single subcorpus - adding more corpora would help.' if $self->interlieved;
    #cluck
    return ${$self->_subcorpora}[0]->query($self->_map_opts(${$self->_subcorpora}[0], \@_));
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

  # multiple corpora: hitnums are needed for paging and interleaved (slow)
  # for this reason alone virtual query with caching is needed
  my %hitinfo;
  my @subcorpora = @{$self->subcorpora};
  # BUG: something wierd here:
  # Use of uninitialized value $opts{"class"} in exists at lib/CWB/Model.pm line 438.
  if (exists $opts{class}) {
    @subcorpora = @{${$self->classes}{$opts{class}}}
      if ( exists ${$self->classes}{$opts{class}} );
    delete $opts{class};
  }
  foreach my $subname (@subcorpora) {
    my $subcorpus = ${$self->_subcorpora}{$subname};
      $CWB::Model::exception_handler->("Query called on a virtual corpus with class containing nonexisting subcorpus $subname, skipping subicorpus.\n") and next
	unless $subcorpus and ref $subcorpus and $subcorpus->can('query');
    $hitinfo{$subcorpus->name}{hits} = $subcorpus->query($self->_map_opts($subcorpus, \%opts), hitsonly=>1);
#    $hitinfo{$subcorpus->name}{hits} = $subcorpus->query(%opts, hitsonly=>1);
  }
  my $result = $self->_make_result(%opts);
  if ($opts{display} and $opts{display} eq 'wordlist') {
    # handle wordlist
    $opts{subcorpus => 1}; # disables sorting in subcorpus queries
    my %counts = ();
    foreach  (@subcorpora) {
      my $subcorpus = ${$self->_subcorpora}{$_};
      next unless $subcorpus and ref $subcorpus and $subcorpus->can('query');
      my $sc_name = $subcorpus->name;
      my $r = $subcorpus->query($self->_map_opts($subcorpus, \%opts,));

      $result->query($r->query) unless $result->query;
      $result->QUERY($r->QUERY) unless $result->QUERY;
      $result->hitno($result->hitno + $r->hitno);

      # aggregate from result hits back into counts
      foreach my $hit ( @{$r->hits} ) {
	my $match = $hit->[2][0];
	$counts{$match}{count} =   0 unless exists $counts{$match};
	$counts{$match}{count} +=  $hit->[1];
	$counts{$match}{value} =   $hit->[0];
      }
    }
    # nasty: copied from query handling
    @{$result->hits} = map { [$counts{$_}{value}, $counts{$_}{count}] }
      reverse sort {
	my $c = ($counts{$a}{count} <=> $counts{$b}{count});
	$c ? $c : ($b cmp $a )
	       }  keys %counts;

    ${$result->pages}{single} = 1;
    ${$result->pages}{this} = 1;
    $result->table(1);
    $result->distinct(scalar keys %counts);

  } else {
    # normal queries
    my $offset   = sprintf('%d', ($opts{startfrom} / @subcorpora)) + 0;
    my $pagesize = sprintf('%d', ($opts{pagesize}  / @subcorpora)) + 0;
    # that was naive: ratio not taken into account
    if ($self->interleaved) {
      # interleaved
      # BUG - missing sentnce / paragraph displays
      foreach  (@subcorpora) {
	my $subcorpus = ${$self->_subcorpora}{$_};
	next unless $subcorpus and ref $subcorpus and $subcorpus->can('query');
	my $sc_name = $subcorpus->name;
	my $r = $subcorpus->query($self->_map_opts($subcorpus, \%opts,
						   startfrom => $offset,
						   pagesize => $pagesize
						  ));
	$_->{subcorpus_name} = $sc_name foreach (@{$r->hits});
	$result->query($r->query) unless $result->query;
	$result->QUERY($r->QUERY) unless $result->QUERY;
	$result->hitno($result->hitno + $r->hitno);
	$result->distinct($result->distinct + $r->distinct) if $r->distinct;
	push @{$result->hits}, @{$r->hits};
      }
    } else {
      # sequential NOT FINISHED --- BUG
      # sequential subcorpora: check into which subcorpus we fall
      # rethink to be more objective and query hits on the fly
      foreach (@subcorpora) {
	my $subcorpus = ${$self->_subcorpora}{$_};
	$hitinfo{$subcorpus->name}{start} =
	  ($opts{startfrom} - $offset > 1
	   and $opts{startfrom} - $offset <= $hitinfo{$subcorpus->name}{hits}) ?
	     $opts{startfrom} - $offset : undef;
	$hitinfo{$subcorpus->name}{pagesize} =
	  $opts{startfrom} - $offset < 1 ?
	    $opts{pagesize} + $opts{startfrom} - $offset : $opts{pagesize};
	$offset += 0;
      }
    }
    $result->attributes(exists $opts{show} ? $opts{show} : [[]]);
    $result->aligns(exists $opts{aligns} ? $opts{aligns} : []);

    # finalize pages
    $result->page_setup(%opts);
  }

  $result->time(Time::HiRes::gettimeofday() - $query_start_time);


  return $result;
}

package CWB::Model::Query;
use Mojo::Base -base;
use Carp;
use CWB::CQP;
use Encode qw(encode decode);

our $VERSION = '0.9';

has [ qw(corpus model cqp
	cpos query reduce maxhits
	l_context r_context
	hitsonly debug) ] ;
has search      => 'word';
has show        =>  sub { return [] };
has showstructs =>  sub { return [] };
has align       =>  sub { return [] };
has sort        =>  sub { return {} };
has ignorecase  => 1;
has ignorediacritics => 0;
has ignoremeta  => 0;
has startfrom   => 1;
has pagesize    => 25;
has context     => 25;
has display     => 'kwic';
has result      => sub { CWB::Model::Result->new };
has subcorpus   => 1;

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
  weaken($self->model);
  $self->structures(@{$structures}) if $structures;

  # instantiate CQP - but should have more than one in the future
  #                   also pass corpus-specific collation to CQP env
  my $old_collate = $ENV{LC_COLLATE};
  $ENV{LC_COLLATE} = ($self->corpus->language ? $self->corpus->language : 'en_US') . '.' . $self->corpus->Encoding;
  #warn "LC_COLLATE set to: $ENV{LC_COLLATE}\n";
  my $cqp = CWB::CQP->new
    or CWB::Model::exception_handler->('CWB::Model Exception: Could not instantiate CWB::CQP.');
  $ENV{LC_COLLATE} = $old_collate;
  # set registry - needed since we can supercede the ENV and CWB::Config
  $cqp->exec("set registry '" . $self->model->registry . "';");
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
		     } elsif (not m{^\[} and not $self->ignoremeta) {
		       s/(?<!\\)[*]/.*/g;
		       s/(?<!\\)[?]/./g;
		       s/(\[|\])/\\$1/g;
		     }
		     (m{^\[}) ? $_ :
		   '['
		     . (defined $self->search ?
			$self->search : 'word')
		       . '="' . $_ . '"'
		       . ( ( $self->ignorecase or $self->ignorediacritics or $self->ignoremeta ) ? ' %' : '' )
		       . ( $self->ignorecase ? 'c' : '' )
		       . ( $self->ignorediacritics  ? 'd' : '' )
		       . ( $self->ignoremeta  ? 'l' : '' )
		      . ']'
		     } split('\s+', $query)
		  );
    warn("Passing query as $query.\n") if $self->debug;
  } else { #handle CQP escape
    $query =~ s{^\s*[+]?\s*}{};
  }

  # test CQP connection
  $self->exec("show", 'CQP not answering');
  $self->exec("set PrintMode sgml", 'Could not set PrintMode to sgml');

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

  my $bc; my $bigcontext;
    if (grep { $_ } map { $_ eq 'p' }
	@{$self->corpus->structures}) {
      $bc = 'p'; $bigcontext = 'paragraphs';
    }
    if (not $bc and grep { $_ } map { $_ eq 's' }
	@{$self->corpus->structures}) {
      $bc = 's';
      $bigcontext = 'sentences';
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
		"Can't set PrintStructures for $ps");
  } else { #wordlist
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
  $self->exec('set Context ' . $bc . ';',
	      "Can't set context to '" . $bc . "'")
    if defined $bc and $self->cpos;

  my $_query;
  if ($self->cpos) {
    $self->undump($self->cpos);
  } else {
    # execute query (but don't show the results yet)
    $_query = encode($self->corpus->encoding, $query);
    $self->cqp->exec_query($_query); # for tainted execution
    $self->exception("CQP query for $query failed -",
		     $self->cqp->error_message)
      unless $self->cqp->ok;
  }
  # process results into a result object
  my $result = CWB::Model::Result->new(corpusname => $self->corpus->name)
    or $self->exception("Failed to create a result object.");

  $result->query($query);
  $result->QUERY($_query);
  @{$result->attributes} = $self->show;
  @{$result->aligns} = @aligns;
  @{$result->peers} = $self->corpus->peers;
  $result->hitno($self->cqp->exec("size Last"));
  $result->cpos($self->cpos) if $self->cpos;

  # select context display type for hit context presentation - obsoleted?
  $result->bigcontext($bigcontext);

  # hitsonly
  if ($self->hitsonly) {
    $result->time(Time::HiRes::gettimeofday() - $query_start_time);
    return $result;
  }

  # sorting
  if ($self->sort and exists ${$self->sort}{a} and not $self->cpos) {
    $self->exec("set ExternalSort on", 'Could not enable ExternalSort');
    my $sort_cmd = 'sort by ' . ${$self->sort}{a}{att};
    $sort_cmd .= ' %c';
    # sort by attribute on start point .. end point ;
    $sort_cmd .= ' on matchend[1]' if ${$self->sort}{a}{target} eq 'right';
    $sort_cmd .= ' on match[-1]' if ${$self->sort}{a}{target} eq 'left';
    $sort_cmd .= ' descending' if ${$self->sort}{a}{order} eq 'descending';
    $sort_cmd .= ' reverse' if ${$self->sort}{a}{direction} eq 'reversed';
    #warn "Sorting! <<$sort_cmd>>\n";
    $self->exec($sort_cmd, 'Could not perform sort with ' . $sort_cmd);
  } else {
    # set natural sort order
    $self->exec("set ExternalSort off", 'Could not disable ExternalSort');
    $self->exec('sort');
  }

  # reduce?
  if ($self->display eq 'kwic'
      or $self->display eq 'sentences'
      or $self->display eq 'paragraphs') {
    if ($self->reduce and $self->pagesize and not $self->cpos) {
      $self->exec("reduce Last to " . $self->pagesize);
      $result->reduce(1);
    }

    # compute page list for navigation
    my $pages = '';

    if (not $self->cpos) {
      $self->startfrom($result->page_setup(
				      startfrom => $self->startfrom,
				      pagesize => $self->pagesize,
				      reduce => $self->reduce,
				     ));
      $pages = (${$result->pages}{this} -1 . ' ' . (${$result->pages}{next} ? ${$result->pages}{next} - 1 : $result->hitno))
	if $self->pagesize and not $self->reduce;
    }

    my @kwic = $self->cqp->exec('cat Last ' . ($pages ? $pages : ''));
    my $attrs = 0;

    foreach my $kwic (@kwic) {
      if ($kwic =~ m{^[<]attribute type=positional}) { # SGML attr info
	$attrs++;
	next;
      }
      next if $kwic =~ m{^[<](attribute|/?CONCORDANCE)}; # SGML preamble & info
      if ($kwic =~ m{^[<]align name="(.*?)">&lt;CONTENT&gt; (.*)&lt;/CONTENT&gt;$}) { #align - to previous hit
	$self->exception("Found an aligned line without a previous hit:", $kwic)
	  and next
	    unless (scalar @{$result->hits});
	$self->exception("Aligned corpus $1 not found in model, hit was: $2\n")
	unless ${$self->model->corpora}{$1}->isa('CWB::Model::Corpus');
	my $aligned = $1;
	my $align = decode(${$self->model->corpora}{$aligned}->encoding, $2);
	$align =~ s{&(l)?g?t;}{$1 ? '<' : '>'}ge; 	#fix sgml escapes
	${@{$result->hits}[-1]}{aligns}{$aligned} = _tokens($align, $attrs);
      } else { #kwic
	$kwic = decode($self->corpus->encoding, $kwic);
	$kwic =~ m{^[<]LINE[>]        # head
		   [<]MATCHNUM[>]([\d]+)[<]/MATCHNUM[>] # cpos
		   (?:[<]STRUCS[>](.*?)[<]/STRUCS[>])?  # structs
		   [<]CONTENT[>]\s*
		   (.*?)\s*           # left
		   [<]MATCH[>]        # separator
		   (.*?)              # match
		   [<]/MATCH[>]\s*    # separator
		   (.*?)              # right
		   \s*[<]/CONTENT[>]
		   [<]/LINE[>]\s*$}x  # tail
	  or $self->exception("Can't parse CQP kwic output, $attrs attrs, line:", $kwic);
	my ($cpos, $structs, $left, $match, $right) =
	  (
	   $1,
	   $2,
	   _tokens($3, $attrs),
	   _tokens($4, $attrs),
	   _tokens($5, $attrs),
	  );

	$structs =~ s{&(l)?g?t;}{$1 ? '<' : '>'}ge 	#fix sgml escapes
	   if $structs;
	my $data = {};
	if ($structs) {
	  foreach (split '><', substr($structs, 1, -1) )
	    # remove heading/trailing <>
	    {
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
    ${$result->pages}{this} = 1;
    if ($self->reduce and $self->pagesize) {
      $result->reduce(1);
    }
    $result->table(1);
    my @kwic = $self->cqp->exec("cat Last 0 10000"); # limit max, 0-based
    #warn "Got " . scalar @kwic . " lines.\n";
    my %counts;
    my $attrs=0;
    foreach my $kwic (@kwic) {
      if ($kwic =~ m{^[<]attribute type=positional}) { # SGML attr info
	$attrs++;
	next;
      }
      next if $kwic =~ m{^[<]/?CONCORDANCE}; # SGML preamble
      $self->exception("Not expecting alignemnents in frequency wordlists, line:", $kwic)
      if $kwic =~ m{^[<]align name="(.*?)">&lt;CONTENT&gt; (.*)&lt;/CONTENT&gt;$};

      $kwic =~ m{^[<]LINE[>]        # head
		 [<]MATCHNUM[>][\d]+[<]/MATCHNUM[>] # cpos
		 (?:[<]STRUCS[>].*?[<]/STRUCS[>])?  # structs
		 [<]CONTENT[>]\s*
		 .*?\s*           # left
		 [<]MATCH[>]        # separator
		 (.*?)              # match
		 [<]/MATCH[>]\s*    # separator
		 .*?              # right
		 \s*[<]/CONTENT[>]
		 [<]/LINE[>]\s*$}x  # tail
	or $self->exception("Can't parse CQP kwic output for wordlist, line:", $kwic);
      my $match = decode($self->corpus->encoding, $1);
      $match = lc($match) if $self->ignorecase;
      $counts{$match}{count} = 0 unless exists $counts{$match};
      $counts{$match}{count}++ ;
      $counts{$match}{value} = _tokens($match, $attrs);
      $counts{$match}{data} = [$match, $attrs] if $self->subcorpus;
    }
    if ( not $self->subcorpus) {
      @{$result->hits} = map { [
				$counts{$_}{value},
				$counts{$_}{count}
			       ] }
	reverse sort {
	  my $c = ($counts{$a}{count} <=> $counts{$b}{count});
	  $c ? $c : ($b cmp $a )
	}  keys %counts;
    } else { #subcorpus query does not sort (saves time)
      @{$result->hits} = map { [
				$counts{$_}{value},
				$counts{$_}{count},
			       	$counts{$_}{data},
			       ] }
	keys %counts;
    }
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

sub _tokens {
  return [ map { push @$_, "∅" while scalar @$_ < $_[1]; $_; } # fix missing attrs
	   map { [ split '/' ] } $_[0] =~ m{<TOKEN>(.*?)</TOKEN>}g ];
}

sub exec {
  my ($self, $command, $error) = @_;
  $self->cqp->exec($command);
  $self->exception("$error -", $self->cqp->error_message)
    unless $self->cqp->ok;
}

sub undump {
  my ($self, $cpos, $error) = @_;
  $self->cqp->undump('Last', [$cpos, $cpos]);
  $self->exception("$error -", $self->cqp->error_message)
    unless $self->cqp->ok;
}

sub exception {
  shift;
  return $CWB::Model::exception_handler->('CWB::Model Exception: ' . shift, @_);
}

package CWB::Model::Result;
use Mojo::Base -base;

our $VERSION = '0.9';

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

