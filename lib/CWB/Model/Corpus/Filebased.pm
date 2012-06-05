package CWB::Model::Corpus::Filebased;

use Mojo::Base 'CWB::Model::Corpus';

use CWB::Model::Query;
use CWB::Model::Scan;

use Carp;

has [qw(file infofile datahome size)];

sub new {
  my $self = shift->SUPER::new(file => shift, model => shift);

  $self->name(  $self->file =~ m{.*/([^/]+)$} );
  $self->NAME(uc($self->name));

  my $fh = new IO::File;
  $fh->open($self->file, '<:encoding(UTF-8)')
    or croak "CWB::Model::Corpus Exception: Could not open " 
      . $self->file . " for reading during corpus init.\n";
  while (<$fh>) {
    $self->title($1)               if m/NAME\s+"([^#]*)"/ ;
    $self->infofile($1)            if m/INFO\s+([^# \n]*)/ ;
    $self->datahome($1)            if m/HOME\s+([^# \n]*)/ ;
    push @{$self->alignements}, $1 if m/ALIGNED\s+([^# \n]*)/ ;
    push @{$self->attributes}, $1  if m/ATTRIBUTE\s+([^# \n]*)/ ;
    push @{$self->structures}, $1  if m/STRUCTURE\s+([^# \n]*)/ ;
    $self->encoding($1)           if m/^##::\s*charset\s+=\s+"?([^"#\n]+)"?/ ;
    $self->language($1)            if m/^##::\s*language\s+=\s+"?([^"#\n]+)"?/ ;
  }
  $fh->close;
  $self->title( ucfirst($self->name) ) unless $self->title;
  push @{$self->attributes}, 'word'
    unless grep { $_ eq 'word' } @{$self->attributes};
  my $datahome = $self->datahome;
  $self->size(`du $datahome`);
  if (-r $datahome and -d $datahome
      and $self->size and $self->size =~ m/^(\d+)/) {
    $self->size($1);
  } else {
    carp "CWB::Model::Corpus Exception: Could not open $datahome for reading during corpus init, aborted: " . $self->name . " dropped from the registry.\n";
    return undef;
  }

  if ($self->infofile and
      $fh->open($self->infofile, '<:encoding(UTF-8)') ) {
    my $lang;
    while (<$fh>) {
      $lang = $1 || 'en'
	and ${$self->description}{$lang} = ''
	  or next if m/^DESCRIPTION\s*([^# \n]*)/;
      ${$self->description}{$lang} .= $_
	if ($lang);
      push @{$self->peers}, $1  if m/PEER\s+([^# \n]*)/ ;
      $self->encoding($1)  #this should go away
	if m/ENCODING\s+([^# \n]*)/ and not $self->encoding;
      ${$self->tooltips}{lc($1)}{$2}{$3 ? $3 : 'en'} = $4
	if m/(ATTRIBUTE|STRUCTURE)\s+([^# \n]+)\s+(?:([^# \n]+)\s+)?"([^#]*)"/ ;
    }
    $fh->close;
    unless (${$self->description}{$lang} or ${$self->tooltips}{attribute}) {
      $fh->open($self->infofile, '<:encoding(UTF-8)');
      ${$self->description}{en} = do { local $/ = <$fh> };
      # add newlines if no html is present
      unless (${$self->description}{en} =~ m{<\w+[^>]*?/?>}ms) {
	${$self->description}{en} =~ s{\n\s*\n}{<br />\n}ms;
      }
    }
  } else {
    #warn 'Could not access info file for ' . $self->file . ": $@\n";
  }

  $self->encoding('utf8')  unless $self->encoding;
  $self->Encoding($self->encoding) ;
  $self->encoding('utf8')  if $self->encoding eq 'UTF-8';
  $self->Encoding('UTF-8') if $self->encoding eq 'utf8';

  $self->language('en_US') unless $self->language;

  my $cwb_describe = 'cwb-describe-corpus -s -r '
    . $self->model->registry . ' '
    . $self->NAME ;
  my $description = `$cwb_describe`;
  if ($description) {
      ${$self->stats}{attributes} = [];
      ${$self->stats}{structures} = [];
      ${$self->stats}{alignements} = [];

    my @description = split(/^/, $description);
    foreach (@description) {
      ${$self->stats}{tokens} = $1 if m/size\s+.tokens.:\s+(\d+)/;
      push @{${$self->stats}{attributes}}, [ $1, $2, $3 ]
	if m/p-ATT\s+(\w+)\s+(\d+)\s+tokens,\s+(\d+)/;
      push @{${$self->stats}{structures}}, [ $1, $2 ]
	if m/s-ATT\s+(\w+)\s+(\d+)/;
      push @{${$self->stats}{alignements}}, [ $1, $2 ]
	if m/a-ATT\s+([^ \t]+)\s+(\d+)/;
    }
  } else {
      return undef;
  }

  return $self;
}

sub registry { shift->model->registry };

# change api to reuse query without reopening corpora?
sub query {
  my $self = shift;
  croak 'CWB::Model::Corpus syntax error: not called as $corpus->query(query => <query>, %opts);' unless @_ >= 2 and scalar @_ % 2 == 0;
  my $q = CWB::Model::Query->new(corpus => $self, model => $self->model, @_);
  return $q unless $q->DOES('CWB::Model::Query'); #exception occured
  return $q->run;
}

sub scan {
  my $self = shift;
  croak 'CWB::Model::Corpus syntax error: not called as $corpus->scan(tokens => <tokens>, %opts);' unless @_ >= 2 and scalar @_ % 2 == 0;
  my $s = CWB::Model::Scan->new(corpus => $self, model => $self->model, @_);
  return $s unless $s->DOES('CWB::Model::Scan'); #exception occured
  return $s->run;
}

sub structures_ {
  return [ grep { m/_/ } @{$_[0]->structures} ];
}

1;
