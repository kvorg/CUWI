package CWB::CUWI::Plugin::Helpers;

use strict;
use warnings;
use base 'Mojolicious::Plugin';

use Mojo::ByteStream 'b';

sub register {
  my ($self, $app) = @_;

  $app->helper(auth =>
sub {
  my $self = shift;
  my $config = $self->app->config;
  my $authcorpus = $self->param('corpus');
  $self->app->log->debug("Checking for auth requirements for " . ($authcorpus || 'undef') . ".");

  if ($authcorpus and exists $config->{corpora}{AUTH}{$authcorpus} and $config->{corpora}{AUTH}{$authcorpus}{domain} ) {
    unless ($self->session('username')) {
      $app->log->debug("Auth triggered for $authcorpus.");
      $self->flash(error => "Corpus $authcorpus requires authentication.") and
	$self->session(redirection => $self->req->url) and
	  $self->redirect_to($config->{root} . '/login/' . $authcorpus);
      return 0;
    }
  } else {
    return 1;
  }
}
);

# use this to redirect - (migh be obsoleted by ParamValidate)
  $app->helper(sanitize =>
 sub {
  my $self = shift;
  my $maxsize = $self->stash('maxsize');

 #ALSO:
 # and $self->param('sort_a') =~ m/^(left|match|right)$/
 # and $self->param('sort_a_order') =~ m/^(ascending|descending)$/
 # and $self->param('sort_a_direction') =~ m/^(natural|reversed)$/

  $self->param('contextsize', 7)
    unless $self->param('contextsize')
      and '' . $self->param('contextsize') =~ m{[0-9]+};
  $self->param('show', 'word')
    unless $self->param('show');
  $self->param('search', 'word')
    unless $self->param('search');
  $self->param('size', 50)
    unless $self->param('size')
      and '' . $self->param('size') =~ m{[0-9]+}
      and $self->param('size') <= $self->app->config->{maxsize};
  $self->param('startfrom', 1)
    unless $self->param('startfrom')
      and '' . $self->param('startfrom') =~ m{[0-9]+};
}
);

  $app->helper(tabulator =>
sub { #$c is controller, means generate contex links
  my ($c, $tokens, $link) = (@_);
  my $st = '<span class="part">'; my $et = '</span>';
  my @attrs; @attrs = $c->param('show') if $link;

  if ($link) {
    #process lines like: [ [ je, V ] [ bil, K ] ]  [ word, POS ]
    my %query; my $i = 0;
    foreach my $attr (@attrs) {
      my $query = join(' ', map {$_->[$i]} @$tokens ) ;
      foreach my $j (0 .. scalar @$tokens - 1) {
	$tokens->[$j][$i] = $c->link_to_here({query=>$query,
					      search=>$attr,
					      display=>'kwic',
					      ignoremeta=>1},
				    sub { return $tokens->[$j][$i] });
      }
      $i++;
    }
  }
  return join(' ',
	      map {
		'<span class="token">' . 
		  $st . join("$et$st", @$_) . $et 
		    . '</span>';
	      } @$tokens
	     );
});

  $app->helper(urlator =>
	       sub {
		 my $c = shift;
		 my $str = shift;
		 return $str unless $str =~ m{^(http|https|ftp|sftp|)://\w+};
		 return $c->link_to($str, $str);
	       }
	      );

  # tooltip generator
  # $toolitip->($controller, anchor_text=> 'title', 'text');
  # $toolitip->($controller, anchor_text=> 'text');
  $app->helper(tooltip =>
		sub {
		  my ($c, $anchor, $title, $text);
		  $text = pop;
		  ($c, $anchor, $title) = @_;
		  $title //= $anchor;
		  return $anchor unless $text;

		  $c->stash('tooltip_id', 0) unless $c->stash('tooltip_id');
		  $c->stash('tooltip_id', $c->stash('tooltip_id') +1 );
		  my $tid = 'ttip' . $c->stash('tooltip_id');
		  $c->stash('tooltipdata', '') unless $c->stash('tooltipdata');
		  my $ttext = "\n<div id='$tid'>\n" . $text . "\n</div>\n";
		  $c->stash('tooltipdata', $c->stash('tooltipdata') . $ttext);
		  return (b("<a class='ttip' href='#$tid' rel='#$tid' title='$title' >$anchor</a>"));
		});

  $app->helper(infotip =>
		sub {
		  my $cb = pop;
		  my ($c, $m, $title, $anchor) = @_;

		  $anchor //= $m->{data}{text_title}
		    if exists $m->{data}{text_title};
		  $anchor //= 'Info';

		  $anchor = substr($anchor, 0, 11) . '...'
		      unless length $anchor < 14;

		  $c->stash('infotip_id', 0) unless $c->stash('infotip_id');
		  $c->stash('infotip_id', $c->stash('infotip_id') +1 );
		  my $tid = 'itip' . $c->stash('infotip_id');

		  return (b("<a class='itip infobox' href='#$tid' rel='#$tid' title='$title' >$anchor</a>\n<span id='$tid' class='infotip'>"  . $cb->() . "</span>" ));
		});

  $app->helper(tabspreader =>
	       sub  {
		 my ($c, $attributes, $left, $match, $right) = @_;

		 $attributes = $attributes->[0] if ref $attributes->[0];

		 my $i = 0;
		 my @row = ();
		 foreach my $att (@{$attributes}) {
		   my $_; #possibly fixing a possible bug in perl's given
		   push @row, [ $att,
				(map { substr($_->[$i], 0, 1) eq '=' ? '_' . $_->[$i] : $_->[$i] } @{$left}),
				(map { substr($_->[$i], 0, 1) eq '=' ? '<< _' . $_->[$i] . ' >>' : '<< ' . $_->[$i]. ' >>' } @{$match}),
				(map { substr($_->[$i], 0, 1) eq '=' ? '_' . $_->[$i]  : $_->[$i] } @{$right}),
			      ];
		   $i++;
		 }
#		 $c->app->log->debug('TAB: ' . $c->dumper(@$attributes), $c->dumper(@row));
		 return @row;
	       });

  $app->helper(matchquery =>
	       sub  {
		 my ($c, $match) = @_;
		 my $attributes =  $c->stash('result')->attributes->[0];
		 my $qmods = $c->stash('result')->QUERYMODS || '';
		 my $query = '+'; 
		 my $mods = '';
		 $mods = ' %'
		   if $c->param('ignorecase')
		     or $c->param('ignorediacritics')
		       or $c->param('ignoremeta');
		 $mods .= 'c' if $c->param('ignorecase');
		 $mods .= 'd' if $c->param('ignorediacritics');
		 $mods .= 'l' if $c->param('ignoremeta');


		 foreach my $m (@{$match->[0]}) {
		   my $i = 0; my @q;
		   foreach my $att (@{$attributes}) {
		     my $q;
		     $q = "$att=\"" . $m->[$i] . '"';
		     push @q, $q;
		     $i++;
		   }
		   #$DB::single = 2;
		   $query .= ' [ ' . join (' & ', @q) . $mods . ' ]';
		 }
		 return $query . $qmods;
	       });

  $app->helper(lselect =>
	       sub {
		 my $c = shift;
		 return map { [ $c->l($_) => $_ ] } @_;
	       }
	      );

  $app->helper(printbyte =>
	       sub {
		 my ($c, $v) = @_;
		 return $v >= 1073741824 ? $c->printnum(sprintf('%.2f', $v/1073741824)) . ' ' . $c->l('GB')
		   : $v >= 1048576 ? $c->printnum(sprintf('%.2f', $v/1048576)) . ' ' . $c->l('MB')
		     : $v >= 1024 ? $c->printnum(sprintf('%.2f', $v/1024)) . ' ' . $c->l('KB')
		       : $c->printnum($v) . ' ' . $c->l('bytes');
	       }
	      );

  $app->helper(printnum =>
	       sub {
		 my $c = shift;
		 my $t = $c->l('thousands_sep');
		 $t = ',' if $t eq 'thousands_sep';
		 my $d = $c->l('decimal_sep');
		 $d = '.' if $d eq 'decimal_sep';
		 my $input = shift;
		 $input = reverse "$input";
		 $input =~ s<^(\d+)\.><${1}D>;
		 $input =~ s<(\d\d\d)(?=\d)(?!\d*\.)><$1$t>g;
		 $input =~ s<^(\d+)D><$1$d>;
		 return reverse $input;
	       }
	      );

} #register

1;
