package CWB::Model::Corpus;

use Mojo::Base -base;

use Carp qw(croak cluck);
use Scalar::Util qw(weaken);

has [qw(name NAME title model)];
has [qw(attributes structures alignements peers)] => sub { return [] };
has [qw(description tooltips stats)]              => sub { return {} };
has encoding => 'utf8';
has Encoding => 'UTF-8';
has language => 'en_US';

sub new {
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

1;
