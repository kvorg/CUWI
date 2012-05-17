package CWB::Model::Corpus::Virtual;

use Mojo::Base 'CWB::Model::Corpus';

use CWB::Model;
use CWB::Model::Result;

use Carp qw(croak cluck);
use Time::HiRes;
use POSIX qw(locale_h);

has subcorpora  => sub { return []; };
has _subcorpora => sub { return {}; };
has classes => sub { return {}; };
has classnames => sub { return []; };
has [qw(model interleaved general_align size)];
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
# CURIOUS: this should work, but fails in t 20
#           $CWB::Model::exception_handler->("Could not map subcorpus $_ from model - subcorpus $_ not instantiated.\n") 
#	     unless ref ${$self->model->corpora}{$_} 
#	       and ${$self->model->corpora}{$_}->isa('CWB::Corpus');
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
      $self->language($subcorpus->language) unless $self->language;

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
    $result->hits([]);

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
  return(%opts);
}

sub query {
  my $query_start_time = Time::HiRes::gettimeofday();

  my $self = shift;
  $CWB::Model::exception_handler->("Query called on a virtual corpus with no subcorpora, aborting.\n") unless scalar @{$self->subcorpora};

  my %opts = @_;
  $opts{startfrom} ||= 0;
  if ($opts{align}
      and scalar @{$opts{align}} == 1
      and ${$opts{align}}[0] == 1
      and $self->general_align) {
      $opts{align} = $self->alignements;
#      warn ("Model: gone for align all, align opt was $opts{align}\n");
  } else {
      delete $opts{align};
#      warn ("Model: no align all.\n");
  }
  $opts{show} = [ 'word' ] unless $opts{show};

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
  $result->attributes(exists $opts{show} ? (ref $opts{show} ? [$opts{show}] : [[$opts{show}]] ) : [[ 'word' ]]);
  $result->aligns(exists $opts{aligns} ? $opts{aligns} : []);

  if ($opts{display} and $opts{display} eq 'wordlist') {
    # handle wordlist
    $opts{subcorpus} = 1; # disables sorting in subcorpus queries
    my %counts = ();
    foreach  (@subcorpora) {
      my $subcorpus = ${$self->_subcorpora}{$_};
      next unless $subcorpus and ref $subcorpus and $subcorpus->can('query');
      my $sc_name = $subcorpus->name;
      my $r = $subcorpus->query($self->_map_opts($subcorpus, \%opts,));

      $result->query($r->query) unless $result->query;
      $result->QUERY($r->QUERY) unless $result->QUERY;
      $result->hitno($result->hitno + $r->hitno);

      # aggregate from result hits
      foreach my $hit ( @{$r->hits} ) {
	my $match = $hit->[2][0];
	$counts{$match}{count} =   0 unless exists $counts{$match};
	$counts{$match}{count} +=  $hit->[1];
	$counts{$match}{value} =   $hit->[0];
      }

    }
    # compile back hits
    @{$result->hits} = map { [
			      $counts{$_}{value},
			      $counts{$_}{count}
			     ] } keys %counts;

    # sorting
    if ($opts{sort} and exists $opts{sort}{a} and $opts{sort}{a}{target} =~ m{match|order}) {
      $result->sort(%{$opts{sort}{a}});
    } else {
      $result->sort(target=>'order', normalize=>1, order=>'descending');
    }

    ${$result->pages}{single} = 1;
    ${$result->pages}{this} = 1;
    $result->table(1);
    $result->distinct(scalar @{$result->hits});

  } else {
    # normal queries
    my $offset   = sprintf('%d', ($opts{startfrom} / @subcorpora)) + 0;
    my $pagesize = sprintf('%d', ($opts{pagesize}  / @subcorpora)) + 0;
    # that was naive: ratio not taken into account
    if ($self->interleaved) {
      # interleaved
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

    # finalize pages
    $result->page_setup(%opts);
  }

  $result->time(Time::HiRes::gettimeofday() - $query_start_time);


  return $result;
}

1;
