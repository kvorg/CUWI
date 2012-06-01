package CWB::CUWI::Doc;
use Mojo::Base 'Mojolicious::Controller';

# liberaly copied from Mojolicious::Plugin::PODRenderer by Sebastian Riedel
use Mojo::Asset::File;
use Mojo::ByteStream 'b';
use Mojo::DOM;
use Mojo::Util 'url_escape';
use Pod::Simple::HTML;
use Pod::Simple::Search;

our $H = Mojo::Home->new;
my @PATHS = map { $_, "$_/pods" } @INC, $ENV{MOJO_HOME};
our $PERLDOC;

sub new {
  my $self = shift;
  my $self = $self->SUPER::new(@_);
  $H->parse($self->app->home->rel_dir('templates/Doc'));
  $PERLDOC = $H->slurp_rel_file('perldoc.html.ep');
  return $self;
}

sub doc {
  my $self = shift;

  # Find module
  my $module = $self->param('module');
  $module =~ s|/|\:\:|g;
  my $path = Pod::Simple::Search->new->find($module, @PATHS);

  # Redirect to CPAN
  return $self->redirect_to("http://metacpan.org/module/$module")
    unless $path && -r $path;

  # Turn POD into HTML
  open my $file, '<', $path;
  my $html = _pod_to_html(join '', <$file>);

  # Rewrite links
  my $dom     = Mojo::DOM->new("$html");
  my $perldoc = $self->url_for('/' .$self->app->config->{root} . '/doc/');
  $dom->find('a[href]')->each(
			      sub {
				my $attrs = shift->attrs;
				$attrs->{href} =~ s|%3A%3A|/|gi
				  if $attrs->{href}
				    =~ s|^http\://search\.cpan\.org/perldoc\?|$perldoc|;
			      }
			     );

  # Rewrite code blocks for syntax highlighting
  $dom->find('pre')->each(
			  sub {
			    my $e = shift;
			    return if $e->all_text =~ /^\s*\$\s+/m;
			    my $attrs = $e->attrs;
			    my $class = $attrs->{class};
			    $attrs->{class}
			      = defined $class ? "$class prettyprint" : 'prettyprint';
			  }
			 );

     # Rewrite headers
      my $url = $self->req->url->clone;
      my @parts;
      $dom->find('h1, h2, h3')->each(
        sub {
          my $e = shift;
          my $anchor = my $text = $e->all_text;
          $anchor =~ s/\s+/_/g;
          $anchor = url_escape $anchor, '^A-Za-z0-9_';
          $anchor =~ s/\%//g;
          push @parts, [] if $e->type eq 'h1' || !@parts;
          push @{$parts[-1]}, $text, $url->fragment($anchor)->to_abs;
          $e->replace_content(
            $self->link_to(
              $text => $url->fragment('toc')->to_abs,
              class => 'mojoscroll',
              id    => $anchor
            )
          );
        }
      );

      # Try to find a title
      my $title = 'Perldoc';
      $dom->find('h1 + p')->first(sub { $title = shift->text });

      # Combine everything to a proper response
      $self->content_for(perldoc => "$dom");
      $self->render(inline => $PERLDOC, title => $title, parts => \@parts);
      $self->res->headers->content_type('text/html;charset="UTF-8"');
}

sub _pod_to_html {
  return unless defined(my $pod = shift);

  # Block
  $pod = $pod->() if ref $pod eq 'CODE';

  # Parser
  my $parser = Pod::Simple::HTML->new;
  $parser->force_title('');
  $parser->html_header_before_title('');
  $parser->html_header_after_title('');
  $parser->html_footer('');

  # Parse
  $parser->output_string(\(my $output));
  return $@ unless eval { $parser->parse_string_document("$pod"); 1 };

  # Filter
  $output =~ s|<a name='___top' class='dummyTopAnchor'\s*?></a>\n||g;
  $output =~ s|<a class='u'.*?name=".*?"\s*>(.*?)</a>|$1|sg;

  return $output;
}

1;
