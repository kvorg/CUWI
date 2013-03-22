package CWB::CUWI::Group;

use Mojo::Base -base;

use Carp qw(croak cluck);
use Scalar::Util qw(weaken);

has [qw(name nopeers nobrowse hidden model)];
has [qw( title description )] => sub { return {} };
has [qw( members )] => sub { return [] };
has encoding => 'utf8';
has Encoding => 'UTF-8';
has language => undef;

sub new {
    my $self = shift->SUPER::new(@_);
    if ($self->model and ref $self->model eq 'CWB::Model') {
      # filter missing members
      $self->members([
		      grep { exists $self->model->corpora->{$_} } 
		      @{$self->members}
		     ]) ;
    }
      return $self;
}

sub describe {
  croak 'CWB::CUWI::Group syntax error: not called as $group->describe(<lang>);' unless @_ == 2;
  my ($self, $lang) = @_;
  warn "Getting description for group";
  return $self->description unless ref $self->description;
  return ${$self->description}{$lang} ? ${$self->description}{$lang} : ${$self->description}{en};
}

sub givetitle {
  croak 'CWB::CUWI::Group syntax error: not called as $group->givetitle(<lang>);' unless @_ == 2;
  my ($self, $lang) = @_;
  return $self->name unless  $self->title;
  return $self->title unless ref $self->title;
  return ${$self->title}{$lang} ? ${$self->title}{$lang} : ${$self->title}{en};
}

sub reload {
  cluck 'CWB::CUWI::GROUP: groups do not implement a ->reload() method yet.' ;
}

1;
