package CWB::Model::ParamValidator;

use strict;
use warnings;
use feature qw(switch say);

use base 'Mojolicious::Plugin';
use Mojo::ByteStream;
use Carp qw(croak cluck);
use Scalar::Util  qw(looks_like_number blessed);

our $VERSION = '0.01';

sub register {
    my ($self, $app) = @_;

    # Add "link_to_here" helper (with query)
    $app->helper(param_invalid =>
		 sub {
		   my $c = shift;
		   _process($c, => 'validate', @_);
		 }
	);
    $app->helper(param_normalize =>
		 sub {
		   my $c = shift;
		   _process($c, => 'normalize', @_);
		 }
	);
    $app->helper(param_redirect =>
		 sub {
		   my $c = shift;
		   _process($c, => 'redirect', @_);
		 }
	);
}

sub _process {
  my ($c, $mode) = (shift, shift);
  my $spec = pop;
  croak 'ParamValidator called without a spec hash'
    unless ref $spec eq 'HASH';
  croak 'ParamValidator called without an even option list'
    if scalar @_ % 2;
  my $opts = { @_ };
  my $errors = [];
  my $status = {};

  # scope
  my $scope;
  my $stash = 'CWB::Model::ParamValidator::Stash';
  given ($opts->{scope}) {
    when (not defined) {$scope = $c->params}
    when ('param') { $scope = $c->params }
    when ('req')   { $scope = $c->req->params }
    when ('get')   { $scope = $c->req->url->query->params }
    when ('stash') { $scope = $stash->new($c) }
    default {$scope = $c->params}
  }

  # validate
  foreach my $p ($scope->param) {
    # default
    my $s = $spec->{$p} || undef;
    $s = _merge_spec($p, $spec, $opts->{defaults}, ) and warn "dafaults"
      if exists $opts->{defaults};
    my $v = $scope->param($p);
    my $value;
    ($value, $errors, $status)  = _validate ( $p => $v, $s, $errors, $status);
  # action logic (modify/assign/delete values, collect errors)
  # check required
  }

  $DB::single = 2;
  # result logic
  given ($mode) {
    when ('validate') {
      return undef unless scalar @$errors;
      warn 'ERRORS' and return $errors;

    }
  }
}


sub _validate {
  my ($p, $v, $s, $e, $status) = @_;

  $v = $s->{pre}->(@_) and warn "pre" if exists $s->{pre} and ref $s->{pre} eq 'CODE';

  #promote
  if ($s->{promote} and not (ref $v and ref $v eq  $s->{promote}) ) {
    warn "promote";
    if ( not ref $v) {
      my $code;
      given ($s->{promote}) {
	when ('ARRAY')  { $v = [ $v ] }
	when (/c?HASH/) { $v = { $v => 1 } }
	when ('CODE')   { $code = "$v" and $v = sub { eval($code)  } }
      }
    } elsif (ref $v eq 'HASH' and $s->{promote} eq 'ARRAY')   {
      $v= [ map { $_ => $v->{$_} } keys %$v ]
    } elsif (ref $v eq 'ARRAY' and $s->{promote} eq 'HASH') {
      if (not scalar @$v % 2) {
	$v = [ map { $_ => $v->{$_} } keys %$v ]
      }
    } elsif (ref $v eq 'ARRAY' and $s->{promote} eq 'cHASH') {
      my $hash = {};
      no warnings;
      $hash->{$_}++ foreach @$v;
      $v = $hash;
    } elsif (ref $v eq 'ARRAY' and $s->{promote} eq 'CODE') {
      { my $code = join("\n" . @$v); $v = sub { eval($code) } }
    }
  }

  #type
  given ($s->{type}) {
    # references
    when (not defined) { }
    when ('ref') {
      push @$e, "$p: not of type $s->{type}" and $status->{$p} = 1
	unless ref $v
    }
    when (/ARRAY|HASH|CODE/) {
      warn "Type triggered.";
      push @$e, "$p: not of type $s->{type}" and $status->{$p} = 1
	unless ref $v and ref $v eq $_->{type};
      }
    when ('scalar') {
      push @$e, "$p: not of type $s->{type}" and $status->{$p} = 1
	if ref $v
      }
    default { 
      push @$e, "$p: unknown type  $s->{type}" and $status->{$p} = 1
    }
  }

  #value
  my $vv;
  $vv= [ @$v ] if (ref $v eq 'ARRAY');
  $vv= [ values %$v ] if (ref $v eq 'HASH');
  $vv= [ $v ] unless ref;
  foreach my $v (@$vv) {
    given ($s->{value}) {
      # references
      when (not defined) { }
      when ('ref') {
	push @$e, "$p: not of type $s->{value}" and $status->{$p} = 1
	  unless ref $v
	}
      when (/ARRAY|HASH|CODE/) {
	push @$e, "$p: not of type $s->{value}" and $status->{$p} = 1
	  unless ref $v and ref $v eq $_->{value}
	}
      when ('blessed') {
	push @$e, "$p: not of type $s->{value}"  and $status->{$p} = 1
	  unless blessed $v
	}
      # scalars
      when ('scalar') {
	push @$e, "$p: not of type $s->{value}" and $status->{$p} = 1
	  if ref $v
	}
      when ('boolean')
      { 1 }
      when ('true') {
	push @$e, "$p: not of type $s->{value}" and $status->{$p} = 1
	  unless $v
	}
      when ('true') {
	push @$e, "$p: not of type $s->{value}" and $status->{$p} = 1
	  unless $v =~ m/\w+/
	}
      #numbers
      when ('number') {
	push @$e, "$p: not of type $s->{value}" and $status->{$p} = 1
	  unless looks_like_number($v)
	}
        when (/^int/) {
	  push @$e, "$p: not of type $s->{value}" and $status->{$p} = 1
	    unless looks_like_number($v) and  sprint('%d', $v) == $v
	  }
      when ('positive') {
	push @$e, "$p: not of type $s->{value}" and $status->{$p} = 1
	  unless looks_like_number($v) and $v == abs($v)
	}
      # default
      default {
	push @$e, "$p: unknown type  $s->{value}" and $status->{$p} = 1
      }
    }

  #range

  #set


  }

  $v = $s->{post}->(@_) if exists $s->{pre} and ref $s->{pre} eq 'CODE';

  # fix actions when not promoting
  return $v, $e, $status;
}


sub _merge_spec {
  my ($param, $spec, $default) = @_;
  return $default
    unless exists $spec->{$param} and ref $spec->{$param} eq 'HASH';
  my $s = {};
  $DB::single = 2;
  foreach (keys %{$spec->{$param}}, keys %{$default}) {
    $s->{$_} = undef;
  }
  foreach (keys %{$s}) {
    $s->{$_} = exists $spec->{$_} ? $spec->{$_} : $default->{$_}
  }
  return $s;
}

# stash to param wrapper for scope
{
  package CWB::Model::ParamValidator::Stash;

  sub new {
    my ($this, $c) = @_;
    return bless { c => $c }, ref $this || $this;
  }

  sub c { return shift->{c} ; }

  sub param {
    my $c = shift; #????->{$c};
    return scalar @_ ? $c->stash(@_) : keys %{$c->stash}   ;
  }

  sub params { return shift }; #not emulating parsed setter

  sub remove { return delete shift->c->stash->{$_[0]}; }

}

1;
__END__

=head1 NAME

CWB::Model::ParamValidator - process, validate, normalize params

=head1 SYNOPSIS

    # Mojolicious
    $self->plugin('param_validator');
 
    # Mojolicious::Lite
    plugin 'param_validator';
 
    $c->render (text=>'Faulty parameters')
      if $c->param_invalid( ARGS );
 
    my $errors = $c->param_invalid( ARGS );
    $c->render (text=>"Faulty parameters:\n" . $errors ) if $errors;
 
    $c->param_normalize( ARGS )->render;
 
    $c->redirect_to $c->param_redirect( ARGS );

    # redisplay form if there are errors
    my $errors = $c->param_invalid( scope=>'req', { SPECS } );
    $c->render(template=>'form', param_error => $error) if $errors;
    # then higlight errors in form teplate:
    <%= text_field 'query' %><%= param_error 'query' %>

=head1 DESCRIPTION

L<CWB::Model::ParamValidator> is a parameter validator.It can either
report on errors, normalize parameters or return a redirection URL
with normalized query strings.

L<CWB::Model::ParamValidator> since it uses much simpler syntax where
all data is presented as a data structure.

It can optionally push any errors on the stash (to highlight in a form
when using normalization) or in the flash (to highlight when using
redirection).

=head1 OPTIONS

     $c->param_invalid( scope=>'req', { SPECS } )

=over 

=item * C<scope>

Scope of validation for this call. Value: a string. Valid values:
'param' ($c->param() parameters, the default) 'req' ($c->tx->param()
parameters, GET or POST parameters), 'stash' (all values on the
stash).

Note that redirection will not work on 'stash' scope.

=item * C<defaults>

Default settings for all parameter specifications. Value is a hash
reference. See L>/"VALIDATION SPECIFICATION"> for the meaning of
values.

=item * C<exclusive>

A parameter not covered by the spec is an error it C<exsclusive> is
true.

=back

=head1 VALIDATION SPECIFICATION

Validation specification is passed as a hash reference. Hash keys
specify the parameters. Hash value is a hash reference. Accepted
fields in the has are:

=over

=item * required

Omission of this parameter is treated as an error.

If a default value is specified, C<param_normalize()> will avoid
throwing an error and injest the parameter with a default value
instead.

=item * default

Default value for all parameters mentioned in the specification.

=item * value

Default type for the parameter value or values. Types are:

=over

=item * C<scalar>

Any non-reference value.

=item * C<ref>

Any reference value.

=item * C<blessed>

Any blessed reference.

=item * C<boolean>

Any true or false value, including undef.

=item * C<true>

Any true value.

=item * C<number>

Any numeric value

=item * C<int[eger]>

Positive or negative integer number)

=item * C<positive>

A positive integer

=item * C<word>

Anthing matching qr/\w+/.

=back

=item * C<type>

The perl variable type, defaults to C<scalar>. Acceptable values are
C<scalar>, C<ref> (any reference) and any of the reference types as
retourned by C<ref()>: C<ARRAY>, C<HASH>, C<CODE>.

If a different value is specified, it is taken as the package name of
an object and comparison is done with C<ref()>.

C<param_normalize()> will avoid throwing an error if the actual type
can be promoted and to the specified type and promotion is declared.

=item * C<range>

Acceptable range for the parameter. For numeric parameters, this is an
inclusive test. For strings and arrays, the parameter size is used for
the inclusive test. For hashes, the number of keys is used.

=item * set

Acceptable set of values, as an array. Specifying a set constraint
with a value constraint is superflous in most cases.

=item * promote

Promotion method for the parameter, where the target perl variable
type or promotion method is specified. Acceptable values are:

=over

=item * C<ARRAY>

A single value is promoted to a single member array. A hash is
promoted to an array of keys and values.

=item * C<HASH>

A single value is promoted to a key with value C<1>. An array is
promoted to a hash by treating array members as keys and values as
member count.

=item * C<CODE>

A single value is enclosed in C<sub { eval("...") }>. This is fragile
and should only be used as internal convenience with previously vetted
or internally generated values, obviously.

An array is joined with "\n" to produce a code block.

=item * C<sub {...}>

An anonymous subroutine is specified as the promotor.  Caveat emptor.
I
t is called with the following signature:

  $sub->($validator_class,
         controller => $controller,
         name => $parameter_name,
         value => $parameter_value,
         type => $any_type_specification_in_force,
         error => $error_array_ref,
         )

The subroutine should return the new value. In the case of a problem,
it should push an error status to the $error_array_ref and return
undef.

=back

=item * C<exception>

The exception to be used for this parameter. If not set to a
reference, this is the value returned by the validator when an
exception is to be raised.

If C<undef> is used for the exception, no exception is generated, and
the validator returns true. In this case, any offending parameter is
set to its default value, if available, or deleted. If a parameter is
required but has no default value with this setting, the call is
invalid and the validator will C<croak()>.

=item * C<pre>

The value of this field is an anonymous subroutine. This subroutine is
called before any other tests are performed. Its return value is taken
as the value of the parameter for the remainder of the validation and
normalization, unless the return value is the exception value in force
for the parameter (C<CWB::Model::Exception> by default), which aborts
all other tests.

=item * C<post>

The value of this field is an anonymous subroutine. This subroutine is
called after any other tests are performed. Its return value is taken
as the value of the parameter unless the return value is the
exception, which throws an exception or invalidates the parameter.

=back

