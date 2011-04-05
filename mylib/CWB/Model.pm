package CWB::Model;
use Carp;
use IO::Dir;
use IO::File;
use CWB::Config;

use Mojo::Base -base;

has registry => sub {
  $CWB::CL::Registry = $ENV{CORPUS_REGISTRY}
    ||= CWB::Config::Registry;
} ;
has corpora => sub {
  return {
   map {
     my $corpus = CWB::Model::Corpus->new($_ );
     ($corpus->name, $corpus);
   } grep {
     -f $_  and not ( m{/[#]} or m {[#~]$});
   } map {
     my $dirname = $_;
     map { "$dirname/$_" } IO::Dir->new($dirname)->read;
   } split (':', $CWB::CL::Registry)
  } ;
} ;

our $excepton_handler = sub { die @_ ; } ;

sub install_exception_handler {
  my ($this, $handler) = @_;
  if ( $handler and ref $handler eq 'SUB' ) {
    $excepton_handler = $handler ;
  } else {
    $excepton_handler = sub { die @_ ; } ;
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
use Carp;
use Mojo::Base -base;

has [qw(file infofile name NAME title align encoding)];
has [qw(attributes structures)] => sub { return [] };
has [qw(description tooltips)]  => sub { return {} };

sub new {
  my $self = shift->SUPER::new(file => shift);

  $self->name(  $self->file =~ m{.*/([^/]+)$} );
  $self->NAME(uc($self->name));

  my $fh = new IO::File;
  $fh->open($self->file, '<')
    or die "Could not open $self->file for reading during corpus init.\n";
  while (<$fh>) {
    $self->title($1)    if m/NAME\s+"([^#]*)"/ ;
    $self->align($1)    if m/ALIGN\s+([^# \n]*)/ ;
    $self->infofile($1) if m/INFO\s+([^# \n]*)/ ;
    push @{$self->attributes}, $1 if m/ATTRIBUTE\s+([^# \n]*)/ ;
    push @{$self->structures}, $1 if m/STRUCTURE\s+([^# \n]*)/ ;
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
    $self->encoding('utf8') unless $self->encoding;
    $self->encoding('utf8') if $self->encoding eq 'UTF-8';
    $fh->close;
  } else {
    warn "Could not access info file for $self->file.\n";
  }

  return $self;
}

sub describe {
  croak 'CWB::Model::Corpus syntax error: not called as $corpus->describe(<lang>);' unless @_ == 2;
  return ${shift->description}{shift()};
}

sub tooltip {
  croak 'CWB::Model::Corpus syntax error: not called as $corpus->tooltip(<attribute|structure> <name> <lang>);' unless @_ == 4;
  my ($self, $type, $name, $lang) = @_;
  return ${$self->tooltip}{$type}{$name}{$lang};
}

# change api to reuse query without reopening corpora?
sub query {
  croak 'CWB::Model::Corpus syntax error: not called as $corpus->query(query => <query>, %opts);' unless @_ > 2;
  return CWB::Model::Query->new(shift, @_)->run;
}


package CWB::Model::Query;
use Mojo::Base -base;
use Carp;
use CWB::CQP;
use CWB::CL;

has [qw(corpus query cut reduce size contextsize  parallel)] ;
has search => sub { return [ 'word' ] };
has show =>   sub { return [ 'word' ] };
has ignorecase => 1;
has ignorediacritics => 0;
has startfrom => 1;
has display => 'kwic';
has parallel => 0;
has cqp    => sub { CWB::CQP->new
  or CWB::Model::exception_handler->('CWB::Model Exception: Could not instantiate CWB::CQP.') };
has result => sub { CWB::Model::Result->new };

sub run {
  my $self = shift;
  my $query = $self->query;

  if ( not $query =~ m/"/ ) { # transform into CQP query
    # BUG: possibly CQP metacharacters should be escaped
    $query =~ s/(?<!\\)[*]/.*/gm; $query =~ s/(?<!\\)[?]/./gm;
    $query = join(' ',
		   map {
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
    warn("Passing query as $query.\n");
  }

  # CWB::Web::Query stuff here

  # Probably not needed:
  # $self->exec("set registry '$CWB::CL::Registry';",
  # 	      "Can't change to registry to $CWB::CL::Registry")
}

sub exec {
  my ($self, $command, $error) = @_;
  $self->cqp->exec($cmd);
  $self->exception("$error -", $self->cqp->error_message)
    unless $self->cqp->ok;
}

sub exception {
  return $CWB::Model::exception_handler->('CWB::Model Exception: ' . shift, @_);
}

package CWB::Model::Result;
use Mojo::Base -base;

has [qw(query QUERY time hitno)] ;
has hits => sub { return [] } ;

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
  $corpus->tooltip(attribute => 'pos', 'en);        # English tooltips
  $corpus->tooltip(structure => 'doc', 'en)
  
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

Ideas, resources and possibly code snippets have been borrowed from
CWB moudels by Stefan Evert [http::/purl.org/stefan.evert].

=head1 SEE ALSO

L<CWB::CQP>, L<CWB::CL>, L<http://...> for L<CQP> syntax and general
B<Corpus WorkBench> information.

=cut

