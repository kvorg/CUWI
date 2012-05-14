use lib qw(/home/jona/Projects-ijs/CQP/lib ./lib /home/jona/Projects-ijs/CQP/lib-extra ./lib-extra);
use lib qw( /home/jona/usr/cwb/CQP/lib /home/jona/usr/cwb/CQP/mylib /home/jona/usr/cwb/share/perl5 /home/jona/usr/cwb/lib64/perl5 /home/jona/usr/cwb/lib64/perl5/auto );

package CWB::CUWI;
use Mojo::Base 'Mojolicious';

our $VERSION = '0.41';

use CWB::Model;

use Mojo::Loader;
use IO::File;
use IO::Dir;
use File::Spec;
use File::Temp;
use Encode 'decode';

sub startup {
  my $self = shift;
  push @{$self->plugins->namespaces}, 'CWB::CUWI::Plugin';
  $self->plugin('charset' => {charset => 'UTF-8'});
  $self->plugin('tag_helpers_extra');
  $self->plugin('helpers');
  #$self->plugin('pod_renderer'); #park it under root and use for help?

  $self->defaults->{maxsize} = 50000;
  $self->defaults->{maxpagesize} = 500;

  $self->secret('re9phoothieX4dah4chi');
  $self->types->type(perl => 'application/perl');
  $self->types->type(csv => 'application/csv');
  $self->types->type(xls => 'application/excel');

  my $maxsize = 50000;
  my $maxpagesize = 500;

  my $tabulator;  # multi attribute tabulator callback
  my $columnator; # multi attribute tabulator callback for table columns export
  my $urlator;    # conditional anchor generator
  my $table_export;

  my $loader = Mojo::Loader->new;
  my $e = $loader->load('Spreadsheet::Write');
  if (ref $e) {
    $self->log->info("Module Spreadsheet::Write not available: $e. " .
		     "Install Spreadsheet::Write if you need cvs and excel table result exports.")
  } else {
    $self->log->info("Module Spreadsheet::Write loader said: $e.") if $e;
    $self->log->info("Module Spreadsheet::Write loaded ok.") unless $e;
    $table_export = 1;
  }

# config
# possibly use the config helper?
  my $config = $self->plugin(JSONConfig => {
				     file      => 'cuwi.json',
				     stash_key => 'config',
				     default   => { registry => '/usr/local/share/cwb/registry:/usr/local/cwb/registry' },
				    });
  #stuff me in a helper?
  $self->log->info("Config parsed.");
  $config->{tmp} = (
		    ( defined $config->{tmp}
		      and -d $config->{tmp} and -w defined $config->{tmp} ) ?
		    $config->{tmp} :
		    ( $ENV{MOJO_TMPDIR} || File::Spec->tmpdir )
		   );
  $self->log->info("Temporary directory: $config->{tmp}");
  my $model = CWB::Model->new(
			      ( $config->{registry} ? 
				(registry => $config->{registry}) : () )
			     )
    or die "Could not instantiate CWB::Model, aborting\n";
  $self->defaults->{model} = $model;
  $self->log->info("Instantiated model with registry at '" . $model->registry . "'.");
  $model->install_exception_handler(sub { $self->log->error(@_); return @_;} );
  $self->defaults(model => $model);

  # peers from config groups
  if ($config->{corpora}{GROUPS} #BUG: optimize traversal
      and ref $config->{corpora}{GROUPS} eq 'HASH') {
    $self->log->info('Adding groups from config file to CWB Model.');
    foreach my $group (keys %{$config->{corpora}{GROUPS}}) {
      my @members = @{$config->{corpora}{GROUPS}{$group}};
      foreach my $m (@members) {
	$self->log->error("Configuration file error: Group $group includes corpus $m, but no such corpus is present in the registry.")
	  and next unless exists $model->corpora->{$m};
	push (@{$model->corpora->{$m}->peers}, grep { $_ ne $m } @members);
      }
    }
  }

  # virtauls from config
  if ($config->{corpora}{VIRTUALS} #BUG: optimize traversal
      and ref $config->{corpora}{VIRTUALS} eq 'HASH') {
    $self->log->info('Adding virtual corpora from config file to CWB Model.');
    foreach my $virtual (keys %{$config->{corpora}{VIRTUALS}}) {
      my $corpus = $model->virtual($virtual,
				   ((ref ($config->{corpora}{VIRTUALS}{$virtual}{subcorpora}) eq 'ARRAY') ?
				    $config->{corpora}{VIRTUALS}{$virtual}{subcorpora} :
				    []),
				   ((ref ($config->{corpora}{VIRTUALS}{$virtual}{options}) eq 'HASH') ?
				    %{$config->{corpora}{VIRTUALS}{$virtual}{options}} :
				    ())
				  );
      $corpus->description($config->{corpora}{VIRTUALS}{$virtual}{description})
	if $config->{corpora}{VIRTUALS}{$virtual}{description};
      $corpus->peers($config->{corpora}{VIRTUALS}{$virtual}{peers})
	if $config->{corpora}{VIRTUALS}{$virtual}{peers};
      $corpus->tooltips($config->{corpora}{VIRTUALS}{$virtual}{tooltips})
	if $config->{corpora}{VIRTUALS}{$virtual}{tooltips};
    }
  }

  $self->log->info('CWB Model instantiated with corpora: ' .
		   join(', ', $model->list) . '.');

  # frequency data - this could be moved to Model
  if ( exists $config->{corpora}{OPTIONS}{frequencies}
       and exists $config->{var}
       and -d $config->{var} and -w $config->{var} ) {
    $self->log->info('Checking frequencies in '. $config->{var} . ' ...');
    sub MTIME { 9 }; sub SIZE { 7 };
    foreach my $corpus (values %{$model->corpora}) {
      next unless $corpus->can('datahome');
      $config->{var} .= '/' unless substr($config->{var}, -1) eq '/';
      next if ref $config->{corpora}{OPTIONS}{frequencies} eq 'ARRAY'
	and not grep { $_ eq $corpus->name }
	  @{$config->{corpora}{OPTIONS}{frequencies}};
      my $var = $config->{var} . $corpus->name . '.';
      foreach my $att (@{$corpus->attributes}) {
	my $file = $var . $att . '.freq';
	#      $self->log->debug("$file vs " .  $corpus->datahome . "/$att.lexicon");
	unless (-e $file and -r $file and (stat($file))[SIZE] > 0 and (stat($file))[MTIME] > (stat($corpus->datahome . "/$att.lexicon"))[MTIME]) {
	  if (exists $config->{corpora}{OPTIONS}{maxfreq}
	      and (stat($corpus->datahome . "/$att.lexicon"))[SIZE] > $config->{corpora}{OPTIONS}{maxfreq} ) {
	    $self->log->info("Skipping frequencies for $att in " . $corpus->name . ", file bigger that config option maxfreq.");
	  } else {
	    $self->log->info("Re-generating frequencies for $att in " . $corpus->name . " to $file.");
	    if (! system ( 'cwb-lexdecode -P ' . $att . ' -f -r ' . $model->registry . ' ' . $corpus->NAME . ' | sort -rn > ' . $file) ) {
	      $self->log->error("Re-generating frequiencies for $att in " . $corpus->name . " failed: $?");
	    } else {
	      ${$corpus->stats}{freqs}{$att} = $file;
	    }
	  }
	} else {
	  #file exists
	  ${$corpus->stats}{freqs}{$att} = $file;
	}
      }
    }
    $self->log->info('Frequency check done.');
  } elsif ( exists $config->{corpora}{OPTIONS}{frequencies} ) {
    if ( not exists $config->{var}) {
      $self->log->error("Can not generate frequencies: a var directory needs to be specified in config." );
    } else {
      $self->log->error("Can not generate frequencies: no writable directory at $config->{var}." )
    }
  } else {
    $self->log->info('No frequencies requested, none generated.' )
  }


  $config->{root} =~ s{^(.*)/$}{$1};
  $config->{root} = 'cuwi' unless $config->{root};
  $self->log->info("App web root: '$config->{root}'.");

  # routes and controllers

  my $r = $self->routes->under($config->{root});

  $r->get("/" => sub { $self->sanitize; } =>'index');

  $r->get("/logout" => sub {
	 my $self = shift;
	 $self->session(username=>0);
	 $self->redirect_to('/' . $config->{root} );
       });

  $r->get("/style.css" => sub { shift->render_static('cuwi.css'); });

  $r->get("/icons/Help.png" => sub { shift->render_static('icons/Help.png'); });

  $r->get("/lib/*libfile" => sub { my $c = shift; $c->render_static('lib/' . $c->param('libfile')); });


  $r->get("/:corpus/frequencies/:att" => sub {
	    my $self = shift;
	    return 0 unless $self->auth;
	    my $corpus = ${$self->stash('model')->corpora}{$self->param('corpus')};
	    if ( exists ${$corpus->stats}{freqs}{$self->param('att')} ) {
	      $self->res->headers->content_type('text/plain; charset=' . $corpus->encoding);
	      my $ss = Mojolicious::Static->new(root=>$config->{var});
	      $self->$self->log->info("Serving file " . $ss->root .
				      $corpus->name . '.' . $self->param('att') . '.freq');
	      $ss->serve($self, $corpus->name . '.' . $self->param('att') . '.freq');
	      $self->rendered;
	    } else {
	      $self->redirect_to('index');
	    }
	  });

  $r->get("/:corpus")->to(controller => 'controller', action => 'corpus',
			  model=>$model);

  $r->get("/:corpus/search")->to(controller => 'controller', action => 'search',
			  model=>$model);

$r->any("/login/:corpus" => sub {
  my $self = shift;
  my $authcorpus = $self->param('corpus');
  my $username = $self->param('username');
  my $password = $self->param('password');
  my $domain = $config->{corpora}{AUTH}{$authcorpus}{domain};
  my $auth = $config->{DOMAINS}{$domain};
  my $redirection = $self->session('redirection');
  my $retry = $self->session('retry') || 0;
  my $error = $self->flash('error');

  if ($username and $password and $auth) { #authenticate and redirect back
    $self->app->log->info("Authenticating $username for $domain");
    if ($config->{DOMAINS}{$domain}{$username} eq $password) {
      $self->app->log->info("Authenticated $username for $domain - success.");
      $self->session('username', $username);
      $self->session('retry', 0);
      $self->session('redirection', undef);
      $self->redirect_to(defined $redirection ? $redirection : $config->{root} . "/$authcorpus");
    } else {
      $self->app->log->info("Authentication for $username in $domain failed, retrying.");
      $self->session('retry', ++$retry);
      $self->redirect_to('/' . $config->{root}) and return if $retry > 5;
      $self->render(
		    template=>'login',
		    error => "Authentication error. Try again."
		   );
    }
  } else {
    $self->render(
		  template=>'login',
		  error => $error,
		 );
  }

});



$self->log->info("Ready to serve requests.");

}

1;
