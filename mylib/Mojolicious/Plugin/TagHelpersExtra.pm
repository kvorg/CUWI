package Mojolicious::Plugin::TagHelpersExtra;

use strict;
use warnings;

use base 'Mojolicious::Plugin::TagHelpers';

use Mojo::ByteStream;

# Is today's hectic lifestyle making you tense and impatient?
# Shut up and get to the point!
sub register {
    my ($self, $app) = @_;

    # Add "link_to_here" helper (with query)
    $app->helper(link_to_here =>
		 sub {
		   my $c = shift;
		   my $pp = $c->req->params;

		   # replace
		   if (defined $_[0] and ref $_[0] eq 'HASH') {
		       while ( my($param, $value) = each %{$_[0]} ) {
			 $pp->remove($param); $pp->append($param=>$value);
		       }
		       shift;
		     }
		   # add
		   elsif (defined $_[0] and ref $_[0] eq 'ARRAY') {
		     $pp->append(shift @{$_[0]} => shift @{$_[0]})
		       while @{$_[0]};
		     shift;		   }
		   $self->_tag('a', href=>$c->req->url->query($pp), @_) });

    # Add "multi_check_box" helper
    $app->helper(multi_check_box => 
		 sub { $self->_inputx(shift, shift, value => shift, type => 'checkbox', @_) });
    # Add "radio_button_x" helper - whatever it does
    $app->helper(radio_button_x => 
		 sub { $self->_inputx(shift, shift, value => shift, type => 'radio', @_) });
  }
    sub _inputx {
      my $self    = shift;
      my $c     = shift;
      my $name  = shift;

      # Callback
      my $cb = defined $_[-1] && ref($_[-1]) eq 'CODE' ? pop @_ : undef;
      #pop if @_ % 2;

      my %attrs = @_;
      # die unless $attrs{type} eq 'checkbox' or $attrs{type} eq 'radio' ;

      my $value = $attrs{value};
      my %v = map { $_, 1 } ($c->param($name));
      if (exists $v{$value}) {
	$attrs{checked} = 'checked';
      }

      elsif (scalar $c->param($name) ) {
	delete $attrs{checked};
	warn "We have values, deleted default for $name.\n";
      }
      return $self->_tag('input', name => $name, %attrs, $cb || () );
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

=item link_to_here

    <%= link_to_here %>
    <%= link_to_here => begin %>Reload<% end %>
    <%= link_to_here (class => 'link') => begin %>Reload<% end %>
    <%= link_to_here { page=>++$self->param('page') } => begin %>Next<% end %>
    <%= link_to_here [ colour=>'blue', colour=>'red' => begin %>More colours<% end %>

Generate link to the current URL, including the query.
Hashref arguments replace query values, arrayref arguments append values.

=item multi_check_box

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
