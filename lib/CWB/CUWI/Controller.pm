package CWB::CUWI::Controller;
use Mojo::Base 'Mojolicious::Controller';

sub corpus {
  my $self = shift;
  $self->app->log->info("Got to controller.");
  return 0 unless $self->auth;

  my $corpus = ${$self->stash('model')->corpora}{$self->param('corpus')};

  $self->app->log->info("Redirecting to registry, corpus init aborted.")
    and $self->redirect_to('index')
      and return
	unless $self->param('corpus')
	  and $corpus and $corpus->isa('CWB::Model::Corpus');

  $self->stash(corpus => $corpus);
  return 1;
}

sub search {
  my $self = shift;
  my $config = $self->app->config;
  my $model = $self->stash('model');
  $model->install_exception_handler(sub { $self->app->log->error(@_); $self->stash->{cwbexception} = [@_]; return @_;} );
  return 0 unless $self->auth;

  # to application config
  my $maxsize = $self->stash('maxsize');
  my $maxpagesize = $self->stash('maxpagesize');

  # redirect to peer?
  if ( $self->param('peer')
       and $self->param('peer') ne $self->param('corpus') ) {
    my $query = $self->req->url->query;
    my $url = '/' . $config->{root} . '/' . $self->param('peer') . '/search?';
    $self->$self->log->info('Redirecting query to peer ' . $self->param('peer') . '.');

    $self->redirect_to($url . $query);
  }

  if ($self->param('cpos')) {
    $self->app->log->info('Received cpos query: ' . $self->param('cpos') . ' from ' . $self->tx->remote_address . '.');
  } else {
    $self->app->log->info('Received query: ' . $self->param('query')  . ' from ' . $self->tx->remote_address . '.');
  }
  $self->app->log->info('CWB::Model::Corpus init on "' . $self->param('corpus') . '".');
  my $corpus = ${$self->stash->{model}->corpora}{$self->param('corpus')};

  $self->app->log->info("Redirecting to registry, corpus init aborted.")
    and $self->redirect_to('index')
      and return
	unless $self->param('query')
	  and $corpus and $corpus->isa('CWB::Model::Corpus');

  # sanitize parameters, set defaults (perhaps redirect)
  $self->sanitize; # revert to old logic, ParamValidate in progress
  # NASTY - we now have controller params and these, and some parts
  #         use ones or the others - cleanup
  my %params;
  my %c_attributes = map { $_ => 1 } @{$corpus->attributes};
  my %c_structures = map { $_ => 1 } @{$corpus->structures};
  my %c_aligns     = map { $_ => 1 } @{$corpus->alignements};

  $params{cpos} = $self->param('cpos') 
    if $self->param('cpos') and $self->param('cpos') =~ m/^\d+$/;
  $params{query} = $self->param('query');
  $params{class} = $self->param('class')
    if not $corpus->can('file')
      and $corpus->classes->{class};
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
    $params{align} = ref $self->param('align') eq 'ARRAY' ?
      $self->param('align') : [ $self->param('align') ] ;
    $params{align} = [ grep { $c_aligns{$_} } @{$params{align}} ];
  }
  $params{context} = $self->param('contextsize') ? $self->param('contextsize') . ' words' : '5 words';
  $params{display} = $self->param('display');
  #NASTY - used in tabulator and match templates
  # should be using result
  unless ($params{display} and $params{display} =~ m/^kwic|paragraphs|sentences|wordlist$/) {
    $params{display} = 'kwic';
    $self->param(display => 'kwic');
  }
  $params{startfrom} = $self->param('startfrom') || 1;
  $params{startfrom} = 1 unless $params{startfrom} =~ m/[0-9]+/
		     and $params{startfrom} >= 1
		     and $params{startfrom} <= $maxsize;
  $params{reduce} = 1
    if $self->param('listing') and $self->param('listing') eq 'sample';
  $params{pagesize} = $self->param('size') || 50;
  $params{pagesize} = 50 unless $params{pagesize} =~ m/[0-9]+/
		     and $params{pagesize} >= 1
		     and $params{pagesize} <= $maxpagesize;
  if ( $self->param('sort_a') and $self->param('sort_a') ne 'none') {
    $params{sort}{a}{target}    = $self->param('sort_a');
    $params{sort}{a}{att}       = $self->param('sort_a_att');
    $params{sort}{a}{order}     = $self->param('sort_a_order');
    $params{sort}{a}{direction} = $self->param('sort_a_direction');
  }
  #app->log->debug("Calling query with " . $self->dumper(\%params));

  my $result = $corpus->query(%params);

  if ( $result and $result->isa('CWB::Model::Result') ) {
    $self->app->log->info(
			  'Query processed in '.
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
	  my $tmpdir = File::Temp->newdir(File::Spec->catdir($config->{tmp}, 'cuwi_tmp_XXXXX'), CLEANUP=>1, );
	  my $tmpfile = File::Spec->catfile($tmpdir->dirname, 'cuwi_search_results.' . $self->param('format'));
	  $self->stash(tmpdir => $tmpdir ); # stash it until tx end for cleanup

	  my $h="Spreadsheet::Write"->new(
				   file    => $tmpfile,
				   format  => $self->param('format'),
				   sheet   => 'Results',
				  );
	  my $tabspreader = sub  {
	    my $attributes = shift;
	    my ($left, $match, $right) = @_;

	    $attributes = $attributes->[0] if ref $attributes->[0];

	    my $i = 0;
	    my @row = ();
	    foreach my $att (@{$attributes}) {
	      push @row, [ $att,
			   (map { substr($_->[$i], 0, 1) eq '=' ? '_' . $_->[$i] : $_->[$i] } @{$left}),
			   (map { substr($_->[$i], 0, 1) eq '=' ? '<< _' . $_->[$i] . ' >>' : '<< ' . $_->[$i]. ' >>' } @{$match}),
			   (map { substr($_->[$i], 0, 1) eq '=' ? '_' . $_->[$i]  : $_->[$i] } @{$right}),
			 ];
	      $i++;
	    }
#	    $self->app->log->info('TAB: ' . $self->dumper(@$attributes), $self->dumper(@row));
	    return @row;
	  };

	  if (not $result->table) {
	    # not wordlist
	    foreach my $hit (@{$result->hits}) {
	      my @rows = $tabspreader->($result->attributes, $hit->{left}, $hit->{match}, $hit->{right});
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

	  $self->res->headers->header('Content-Disposition' => 'attachment; filename="cuwi_search_results.' . $self->param('format'));
	  $self->res->headers->content_type('application/' . $self->param('format'));
	  my $ss = Mojolicious::Static->new(root=>'/');
	  $ss->serve($self, $tmpfile)
	    or $self->app->log->info('Export failed, file not found.');
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

1;
