package Mojolicious::Plugin::TagHelpersExtra;

use strict;
use warnings;

use base 'Mojolicious::Plugin::TagHelpers';

use Mojo::ByteStream;

# Is today's hectic lifestyle making you tense and impatient?
# Shut up and get to the point!
sub register {
    my ($self, $app) = @_;

    # Add "multi_check_box" helper

    $app->helper(multi_check_box => 
		 sub { $self->_inputx(@_, type => 'checkbox') });
    $app->helper(radio_button_x => 
		 sub { $self->_inputx(@_, type => 'radio') });
  }
    sub _inputx {
my $self    = shift;
		   my $c     = shift;
		   my $name  = shift;
		   my %attrs = @_;
		   # die unless $attrs{type} eq 'checkbox' or $attrs{type} eq 'radio' ;

		   my $value = $attrs{value};
		   my %v = map { $_, 1 } ($c->param($name));
		   if (exists $v{$value}) {
		     warn "Got $value for $name from " . join (', ', keys %v) . "\n";
		     $attrs{checked} = 'checked';
		   }

		   elsif (scalar $c->param($name) ) {
		     delete $attrs{checked};
		     warn "We have values, deleted default for $name.\n";
		   }
		   return $self->_tag('input', name => $name, %attrs);
}



1;
__END__

=head1 NAME

Mojolicious::Plugin::TagHelpersExtra - Extra Tag Helpers Plugin

=head1 SYNOPSIS

    # Mojolicious
    $self->plugin('tag_helpers_extra');

    # Mojolicious::Lite
    plugin 'tag_helpers_extra';

=head1 DESCRIPTION

L<Mojolicous::Plugin::TagHelpersExtra> is a collection of additional
HTML5 tag helpers for L<Mojolicious>.  Note that this module uses the
EXPERIMENTAL and Mojolicous::Plugin::TagHelpersExtra and might break
without warning!

=head2 Helpers

=over 4

=item multi check_box

    <%= check_box 'languages', value => 'perl', checked => 1 %>
    <%= check_box 'languages', value => 'php' %>
    <%= check_box 'languages', value => 'pyton' %>
    <%= check_box 'languages', value => 'ruby' %>


Generate checkbox input element with value and parse parameters accoring to multiple choices.

You can use checked to select default values.

=head1 METHODS

L<Mojolicious::Plugin::TagHelpers> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 C<register>

    $plugin->register;

Register helpers in L<Mojolicious> application.

=head1 SEE ALSO

L<Mojolicious::Plugin::TagHelpers> L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicious.org>.

=cut
