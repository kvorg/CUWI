package CWB::CUWI::Controller;
use Mojo::Base 'Mojolicious::Controller';
use File::Temp qw( :mktemp);
use File::Spec::Functions 'catdir';
use Mojo::Asset::File;
use Data::Dumper;

sub corpus {
  my $self = shift;
  $self->app->log->debug("Got to controller.");
  return 0 unless $self->auth;

  my $corpus = ${$self->stash('model')->corpora}{$self->param('corpus')};

  $self->app->log->info("Redirecting to registry, corpus init aborted on non-existing corpus" .	($self->param('corpus') ? ' ' . $self->param('corpus') : '') . '.' )
    and $self->redirect_to('index')
      and return
	unless $self->param('corpus')
	  and $corpus and $corpus->isa('CWB::Model::Corpus');

  $self->stash(corpus => $corpus);
  return 1;
}


sub simple {
  shift->search(simple=>1);
}

sub search {
  my $self = shift;
  my %opts; %opts = @_ if @_ and scalar @_ % 2 == 0;;
  my $config = $self->app->config;
  my $model = $self->stash('model');
  $model->install_exception_handler(sub { $self->app->log->error(@_); $self->stash->{cwbexception} = [@_]; return @_;} );
  return 0 unless $self->auth;

  my $chost = $self->tx->remote_address;
  $chost = $self->tx->req->headers->header('X-Forwarded-For')
    if $self->tx->req->headers->header('X-Forwarded-For');

  # to application config
  my $maxhits     = $config->{corpora}{OPTIONS}{maxhits};
  my $maxuserhits = $config->{corpora}{OPTIONS}{maxuserhits};
  my $maxpagesize = $config->{corpora}{OPTIONS}{maxpagesize};
  my $maxfreq     = $config->{corpora}{OPTIONS}{maxfreq};
  my $maxuserfreq = $config->{corpora}{OPTIONS}{maxuserfreq} || $config->{corpora}{OPTIONS}{maxfreq};

  # redirect to peer?
  if ( $self->param('peer')
       and $self->param('peer') ne $self->param('corpus') 
       and ${$self->stash->{model}->corpora}{$self->param('peer')}->isa('CWB::Model::Corpus') )
    {
    my $query = $self->req->url->query;
    my $verb = $opts{simple} ? 'simple' : 'search';
    my $url = '/' . $config->{root} . '/' . $self->param('peer') . "/$verb?";
    $self->app->log->info('Redirecting query to peer ' . $self->param('peer') . '.');

    $self->redirect_to($url . $query);
  }

  if ($self->param('cpos')) {
    $self->app->log->info('Received cpos query: ' . $self->param('cpos') . " from $chost.");
  } else {
    $self->app->log->info('Received ' . $self->param('display') . ' query: \'' . $self->param('query')  . "' from $chost on " . $self->param('corpus') . '.');
  }
  $self->app->log->debug('CWB::Model::Corpus init on "' . $self->param('corpus') . '".');
  my $corpus = ${$self->stash->{model}->corpora}{$self->param('corpus')};

  # corpus settings overrule global settings for wordlist hit limits
  $maxhits = $corpus->maxhits || $maxhits;
  $maxuserhits = $corpus->maxuserhits || $maxuserhits;
  #$maxfreq = $corpus->maxfreq || $maxfreq;
  #$maxuserfreq = $corpus->maxuserfreq || $maxuserfreq;

  $self->app->log->info("Redirecting to registry, corpus init aborted.")
    and $self->redirect_to('index')
      and return
	unless ($self->param('query') or $self->param('simple_query'))
	  and $corpus and $corpus->isa('CWB::Model::Corpus');


  # sanitize parameters, set defaults (perhaps redirect)
  my %params;
  my %c_attributes = map { $_ => 1 } @{$corpus->attributes};
  my %c_structures = map { $_ => 1 } @{$corpus->structures};
  my %c_aligns     = map { $_ => 1 } @{$corpus->alignements};

  $params{maxhits} = $self->session('username')  ?
    $maxuserhits : $maxhits;
  $params{maxfreq} = $self->session('username') ?
    $maxuserfreq : $maxfreq
	if $maxfreq;
  $params{startfrom} = $self->param('startfrom') || 1;
  $params{startfrom} = 1 unless $params{startfrom} =~ m/[0-9]+/
		     and $params{startfrom} >= 1;
  $params{class} = $self->param('class')
    if $corpus->isa('CWB::Model::Corpus::Virtual')
      and ${$corpus->classes}{$self->param('class')};
  #warn "Class param set to $params{class}\n";
  $params{context} = $self->param('contextsize') ? $self->param('contextsize') . ' words' : '5 words';

  if ($opts{simple}) {
    my @candidates = (qw( word lemma nform mform ));
      @candidates = @{$config->{corpora}{OPTIONS}{simple_search_attributes}}
	if exists $config->{corpora}{OPTIONS}{simple_search_attributes};
    @candidates = grep { $c_attributes{$_} } @candidates;
    $params{query} = '+ ' . join(' ', map {
      my $q = $_;
      if ( not m{^["[]} ) {
	$q =~ s{[*]}{.*}; $q =~ s{[?]}{.}; $q = '"' . $q . '"';
      }
      if ( m{^[[]} ) {
	$q;
      } else {
	'[ ' . join (' | ', map { qq{$_=$q} } @candidates ) . ' %c ]';
      }
    } split (/\s+/, $self->param('simple_query')));

    $params{show} = ['word'];
    $params{display} = 'kwic';
    $self->param('display', 'kwic');

  } else {
    $self->sanitize; # revert to old logic, ParamValidate in progress
    # NASTY - we now have controller params and these, and some parts
    #         use ones or the others - cleanup

    $params{cpos} = $self->param('cpos')
      if $self->param('cpos') and $self->param('cpos') =~ m/^\d+$/;
    $params{query} = $self->param('query');
    $params{search} = ( $self->param('search')
			&& $c_attributes{$self->param('search')}
			? $self->param('search') : 'word');
    $params{within} = $self->param('within')
      if ($self->param('within')
	  and not $self->param('within') eq '-'
	  and not $self->param('within') =~ m/_/
	  and $c_structures{$self->param('within')} );
    $params{ignorecase} = $self->param('ignorecase');
    $params{ignorediacritics} = $self->param('ignorediacritics');
    $params{ignoremeta} = $self->param('ignoremeta') || 0;
    $params{struct_constraint_struct}  = $self->param('in-struct')
      if $self->param('in-struct')
	and $self->param('in-struct') =~ m/_/
	  and $c_structures{$self->param('in-struct')};
    $params{struct_constraint_query} = $self->param('struct-query');
    $params{align_query_corpus} = $self->param('in-align')
      if $self->param('in-align') and $c_aligns{$self->param('in-align')};
    $params{align_query_not} = $self->param('not-align');
    $params{align_query} = $self->param('align-query');
    if ($self->param('show')) {
      $params{show} = ref $self->param('show') eq 'ARRAY' ?
	$self->param('show') : [ $self->param('show') ] ;
      $params{show} = [ grep { $c_attributes{$_} } @{$params{show}} ];
      $params{show} = ['word'] unless @{$params{show}};
    } else {
      $params{show} = ['word'];
    }
    #NASTY - used in tabulator and match templates
    # should be using result
    $self->param(show => $params{show});
    if ($self->param('align')) {
      $self->app->log->debug('Got align option.');
      #warn ($self->dumper($self->param('align')));
      if ( not ref $self->param('align') and $self->param('align') == 1 ) {
	#general align for virutal corpora
	$params{align} = 1;
	$self->app->log->debug('General align option set.');
      } else {
	$params{align} = ref $self->param('align') eq 'ARRAY' ?
	  $self->param('align') : [ $self->param('align') ] ;
	$params{align} = [ grep { $c_aligns{$_} } @{$params{align}} ];
      }
    }
    $params{display} = $self->param('display');
    #NASTY - used in tabulator and match templates
    # should be using result
    unless ($params{display} and $params{display} =~ m/^kwic|paragraphs|sentences|wordlist$/) {
      $params{display} = 'kwic';
      $self->param(display => 'kwic');
    }
    $params{reduce} = 1
      if $self->param('listing') and $self->param('listing') eq 'sample';
    $params{pagesize} = $self->param('size') || 50;
    $params{pagesize} = 50 unless $params{pagesize} =~ m/[0-9]+/
		     and $params{pagesize} >= 1
		       and $params{pagesize} <= ($maxpagesize || 10000);
    if ( $self->param('sort_a') and $self->param('sort_a') !~ m{none|order} ) {
      $params{sort}{a}{target}    = $self->param('sort_a');
      $params{sort}{a}{att}       = $self->param('sort_a_att');
      $params{sort}{a}{order}     = $self->param('sort_a_order');
      $params{sort}{a}{direction} = $self->param('sort_a_direction');
      unless (grep {$_ eq $params{sort}{a}{att}} @{$params{show}} ) {
	#set first show att to sort if wrong att is used
	$params{sort}{a}{att} = $params{show}[0];
	$self->param('sort_a_att', $params{show}[0]);
      }
    }
  #$self->app->log->debug("Calling query with " . $self->dumper(\%params));

  }
  my $result = $corpus->query(%params);

  if ( $result and $result->isa('CWB::Model::Result') ) {
    $self->app->log->info( 'Processed ' . $self->param('display') .
			  ' query \'' . $self->param('query') . "'" .
			  ($self->session('username') ?
			   ' by ' . $self->session('username') : '') .
			   " from $chost" .
			   ' on ' . $corpus->name .
			   ' with cqp query \'' . $result->query . '\' in ' .
			  sprintf('%0.3f', $result->time) . ' s ' .
			  'with ' . $result->hitno . ' hits.' );
  } else {
    $self->app->log->error("Query failed: $result."); #handle fail
    $self->render( text=>"Query failed: $result" );
    return;
  }

  if ($self->param('cpos') and $self->param('cpos') =~ m/^\d+$/) {
    $self->render( template=>'cpos',
		   result=>$result,
		   corpus=>$corpus,
		 ) ;
  } elsif ($self->param('format')
	   and grep { $_ eq $self->param('format') }
	   qw(xls xls csv json perl)  ) {
    $self->app->log->info('Exporting as ' . $self->param('format')
			  . ' (' . scalar @{$result->hits} . ' hits).');
    given ($self->param('format')) {
      when ('json') { $self->render(json => { %{$result} } ); }
      when ('perl') { $self->render(text => $self->dumper($result), format=>'perl' ); }
      when (/csv|xls/)  {
	if ($self->stash->{table_export}) {
	  my $tmpfile = mktemp(File::Spec->catdir($self->app->config->{tmp}, 'cuwi_tmp_XXXXX'));
	  $self->app->log->debug("Tmpfile for asset: $tmpfile");

	  my $h="Spreadsheet::Write"->new(
				   file    => $tmpfile,
				   format  => $self->param('format'),
				   sheet   => 'Results',
				  );

	  if (not $result->table) {
	    # not wordlist, BUG: fragile with large results
	    foreach my $hit (@{$result->hits}) {
	      #warn Dumper($result->attributes);
	      my @rows = $self->tabspreader($result->attributes, $hit->{left}, $hit->{match}, $hit->{right});
	      $h->addrow( map { {content => $_, type=>'string' } } join (', ', 'cpos: ' . $hit->{cpos} .
									 (exists $hit->{subcorpus} ? '@' . $hit->{subcorpus} : ''),
									 (map {$_ . ': ' . $hit->{data}{$_} } keys %{$hit->{data}} )),
			  @{shift @rows});
	      if (@rows) {
		foreach my $row (@rows) {
		  $h->addrow( map { {content => $_, type=>'string' } } '', @{$row});
		}
	    }
	      foreach (keys %{$hit->{aligns}}) {
		$h->addrow( map { {content => $_, type=>'string' } } '@' . $_, join(' ', map { $_->[0] } @{${$hit->{aligns}}{$_}}));
	      }
	    }
	  } else {
	    #wordlist
	    foreach my $hit ( @{$result->hits} ) {
	      $h->addrow(
			 { content => join(" ", map { @{$_} } @{$hit->[0]} ), type=>'string' },
			 { content => $hit->[1], type=>'number'}
			);
	    }
	  }
	  $h = undef;
	  my $asset = Mojo::Asset::File->new(path => $tmpfile);
	  $asset->cleanup(1);
	  $self->res->headers->header('Content-Disposition' => 'attachment; filename="cuwi_search_results.' . $self->param('format'));
	  $self->res->headers->content_type('application/' . $self->param('format'));
	  $self->res->content->asset($asset);
	  $self->rendered;
	  } else { $self->render(text => 'Perl package Spreadsheet::Write not installed. Sorry.') };
      }
      default { $self->render(text=>'This was impossible, so you are not reading it.');  }
    }
  } else {
    $self->render( template=>'search',
		   result=>$result,
		   corpus=>$corpus,
		 );
  }
}

sub scan {
  my $self = shift;
  my $config = $self->app->config;

  # redirect to peer?
  if ( $self->param('peer')
       and $self->param('peer') ne $self->param('corpus') ) {
    my $query = $self->req->url->query;
    my $url = '/' . $config->{root} . '/' . $self->param('peer') . '/scan?';
    $self->app->log->info('Redirecting scan query to peer ' . $self->param('peer') . '.');

    $self->redirect_to($url . $query);
  }

  my $corpus = ${$self->stash->{model}->corpora}{$self->param('corpus')};
  my $columns = $self->param('columns') || 4;
  my %fields = ( query => '',
		 token => 'word',
		 pos => 0,
		 case => 0,
		 diacritics => 0,
	       );
  my $tokens = [];

  foreach my $column (0 .. $columns) {
    my $token = { %fields };
    foreach my $row ( keys %fields ) {
      $token->{$row} = $self->param("f${row}_$column")
	if defined $self->param("f${row}_$column");
    }
    push @$tokens, $token;
  }

  # check parameters etc
  my %c_attributes = map { $_ => 1 } @{$corpus->attributes};
  my %c_structures = map { $_ => 1 } @{$corpus->structures};

  my %params;
  $params{within} = $self->param('within')
    if ($self->param('within')
	and not $self->param('within') eq '-'
	and not $self->param('within') =~ m/_/
	and $c_structures{$self->param('within')} );
  $params{ignorecase} = $self->param('ignorecase');
  $params{ignorediacritics} = $self->param('ignorediacritics');
  $params{ignoremeta} = $self->param('ignoremeta') || 0;
  $params{struct_constraint_struct}  = $self->param('in-struct')
    if $self->param('in-struct')
	and $self->param('in-struct') =~ m/_/
 	and $c_structures{$self->param('in-struct')};
  $params{tokens} = $tokens;
  # missing:
  # from to freqlimit rangefile outfile

  $self->app->log->debug("Calling scan with " . $self->dumper(\%params));

  my $result = $corpus->scan(%params, debug => 1);

  $self->render(
		corpus => $corpus,
		result => $result,
		template=>'scantest',
		query=>$self->dumper([ $self->req->params->params, $tokens, $result ]),
	       );
}

1;
