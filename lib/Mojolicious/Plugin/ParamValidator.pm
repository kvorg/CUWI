package Mojolicious::Plugin::ParamValidator;

use strict;
use warnings;
use base 'Mojolicious::Plugin';

our $VERSION = '0.0001';

use Mojo::ByteStream;

sub register {
    my ($self, $app) = @_;

    # Add "link_to_here" helper (with query)
    $app->helper(param_invalid =>
		 sub {
		   my $c = shift;
		   
		 }
	);
    $app->helper(param_normalize =>
		 sub {
		   my $c = shift;
		 }
	);
    $app->helper(param_redirect =>
		 sub {
		   my $c = shift;
		 }
	);

sub process {
    my $c = shift;
}

1;
__END__

=head1 NAME

Mojolicious::Plugin::ParamValidator - process, validate, normalize params

=head1 SYNOPSIS

    # Mojolicious
    $self->plugin('tag_helpers_extra');

    # Mojolicious::Lite
    plugin 'tag_helpers_extra';

    $c->render (text=>'Faulty parameters')
      if $c->param_invalid( ARGS );

    my $errors = $c->param_invalid( ARGS );
    $c->render (text=>"Faulty parameters:\n" . $errors ) if $errors;

    $c->param_normalize( ARGS )->render;

    $c->redirect_to $c->param_redirect( ARGS );

=head1 DESCRIPTION

L<Mojolicous::Plugin::ParamValidator> is a parameter validator for
L<Mojolicious>. It can either report on errors, normalize parameters
or return a redirection URL with normalized query strings.

L<Mojolicous::Plugin::ParamValidator> does not use L<Input::Validator>
since it uses much simpler syntax where all data is presented as a
data structure.

It can optionally push any errors on the stash (to highlight in a form
when using normalization) or in the flash (to highlight when using
redirection).

=head1 OPTIONS
     $c->param_invalid( scope=>'req', { SPECS } )

=over 

=item * scope

Scope of validation for this call. Value: a string. Valid values:
'param' ($c->param() parameters, the default) 'req' ($c->tx->param()
parameters, GET or POST parameters), 'stash' (all values on the
stash).

Note that redirection will not work on 'stash' scope.

=item * defaults

Default settings for all parameter specifications. Value is a hash
reference. See L>/"VALIDATION SPECIFICATION"> for the meaning of
values. Accepted fields in the hash are:

=over

=item * required

Needs a default value for each parameter or param_normalize will throw
an exception on missing parameters.

=item * default

Default value for all parameters mentioned in the specification.

=item * type

Default type for all parameters mentioned in the specification.

=item * range

Default range for all parameters mentioned in the specification.

=item * set

Default value set q¸ for all parameters mentioned in the specification.

=back

=back

=head1 VALIDATION SPECIFICATION

Validation specification is passed as a hash reference.
