package CWB::Model;
use Mojo::Base -base;

use CWB::Model::Corpus;
use CWB::Model::Corpus::Filebased;
use CWB::Model::Corpus::Virtual;
use CWB::Model::Query;
use CWB::Model::Result;

use Carp;
use IO::Dir;
use IO::File;
use CWB::Config;
use utf8;


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

