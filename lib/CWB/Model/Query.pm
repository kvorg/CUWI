package CWB::Model::Query;
use Mojo::Base -base;

use CWB::Model;
use CWB::Model::Result;

use CWB::CQP;

use Carp;
use Encode qw(encode decode);
use Scalar::Util qw(weaken);
use Time::HiRes;

our $VERSION = '0.9';

has [ qw(corpus model cqp
	cpos query
        struct_constraint_struct struct_constraint_query within
	align_query align_query_corpus align_query_not
        reduce maxhits
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
has subcorpus   => 0;

sub new {
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

sub _mangle_query {
  my ($self, $query, $noatt) = @_;
  my $org = $query;
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
    warn("Mangled query $org as $query.\n") if $self->debug;
  } else { #handle CQP escape
    $query =~ s{^\s*[+]?\s*}{};
  }
  return $query;
}

sub _mangle_search {
  my ($self, $search) = @_;
  $search =~ s/(?<!\\)[*]/.*/g;
  $search =~ s/(?<!\\)[?]/./g;
  $search =~ s/(\[|\])/\\$1/g;
  return $search;
}


sub run {
  my $self = shift;
  $self->exception("No queriable corpus passed to CWB::Model::Query: aborting run. ")
    and return
      unless ref $self->corpus and $self->corpus->isa('CWB::Model::Corpus::Filebased');

  my $query_start_time = Time::HiRes::gettimeofday();

  my $cqpquery = 0;
  $cqpquery = 1 if $self->query =~ m{s*[+]};
  my $query = $self->_mangle_query($self->query);

  # handle additional constraints
  unless ($cqpquery) {
    # BUG: perhaps some kind of warning should be produced on illogical options,
    # i.e. inexisting corpora and the like?

    # structural constraint
    my $struct_constraint_struct;
    my $struct_constraint_query;
    my $structq = '';
    if ($self->struct_constraint_struct
	and (grep { $_ eq $self->struct_constraint_struct}
	     @{$self->corpus->structures})
	and $self->struct_constraint_query) {
      $struct_constraint_struct = $self->struct_constraint_struct;
      $struct_constraint_query =
      $self->_mangle_search($self->struct_constraint_query);
    }
    $structq = " :: match.$struct_constraint_struct=\"$struct_constraint_query\""
      if $struct_constraint_struct;

    # query on aligned corpus constraint
    my $align_query;
    my $align_query_corpus;
    my $alignq = '';

    # handle generic corpus align constraint
    $self->align_query_corpus(${$self->corpus->alignements}[0]) if
      $self->align_query_corpus and $self->align_query_corpus eq '*' and scalar @{$self->corpus->alignements};

    if ($self->align_query_corpus
	and (grep { $_ eq $self->align_query_corpus}
	     @{$self->corpus->alignements})
	and $self->align_query) {
      $align_query = $self->_mangle_search($self->align_query);
      $align_query_corpus = ${$self->model->corpora}{$self->align_query_corpus}->NAME;
      $alignq = " :$align_query_corpus " .
	( $self->align_query_not ? '! ' : '') .
	  "\"$align_query\"";
    }

    # within structure constraint
    my $within;
    my $withinq = '';
    $within = $self->within
      if $self->within and (grep { $_ eq $self->within} @{$self->corpus->structures});
    $withinq = " within $within" if $within;

    # compose query
    $query .= "$alignq$structq$withinq";
  }

  warn("Constructed query $query.\n") if $self->debug;


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
  $self->exec('set Context 0 words;', "Can't set context to '0 words'")
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
      my $matchkey = $match;
      $matchkey = lc($match) if $self->ignorecase;
      $counts{$matchkey}{count} = 0 unless exists $counts{$matchkey};
      $counts{$matchkey}{count}++ ;
      $counts{$matchkey}{value} = _tokens($match, $attrs);
      $counts{$matchkey}{data} = [$match, $attrs] if $self->subcorpus;
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

1;
