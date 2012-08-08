=head1 NAME

CUWI Manual - Corpus Users' Web Interface Administration Manual

=head1 OVERVIEW

B<*** documentation in progress, stand by ***>

This document contains documentation intended for configuration,
administration and the running of the CUWI Web interface. Please use
the provided INSTALL document for installation information. See also
the included README and supplied examples in C<doc/examples/>.

In general, you should do the following:

=over 4

=item *

Decide on a home for your application - by default, this should be the
location of CUWI.pm. If this is not practical, you can set it by
setting the MOJO_HOME environment variable. If you do this, however,
you should also copy the included C<public/> and C<templates/> directories.

Alternatively, you can use the C<appdir> configuration variable.

=item *

Copy the config file from C<doc/examples/cuwi.conf> to the location of
application home or an alternative location, specified with the
CUWI_CONFIG environemnt variable.

=item *

Create a C<log/> directory in the application home, if you want CUWI
to write logs. Alternatively, use C<logdir> and C<appname>
configuration variables to override the location and name of log
files.

=item *

Edit the config file. At least change the registry to the location of
your CWB registry.

=item *

Test-run the application:

  $ morbo scripts/cuwi

=item *

Kill the development server and try the production server:

  $ hypnotoad scripts/cuwi

=item *

Create a service file for your operating system. If needed, change the
port or set up a proxy service.

=back

The rest of this documents gives all the gory details.


=head1 CONFIGURATION FILE

CUWI uses a L<Mojolicious::Plugin::Config> for its configuration. By
default, it reads a file named C<cuwi.conf>, but you can supply
different configuration files for different running modes, namely
C<cuwi.production.conf> for production mode (when run under hypnotoad,
CGI or other deployment, or when C<MOJO_MODE> is set to "production"),
C<cuwi.testing.conf> for tests and and C<cuwi.development.conf> for
development mode (when run under C<Morbo> development server).

CUWI will look for the configuration file in its home directory, which
is the directory C<CUWI.pm> resides in by default, but can be changed
by setting the C<MOJO_HOME> environment variable. You can also set the
location of the configuration file with the CUWI_CONFIG environemnt
variable, which can be a relative or absolute path to the file. Note
that even if you set an absolute path, ie. C</etc/mycuwi.conf>, CUWI
will still use mode-specific configuration files, if available
(C</etc/mycuwi.production.conf> and C</etc/mycuwi.development.conf> in
this case). In combination with C<registry>, C<var>, C<root>,
C<appname> and C<logdir> configuration variables, this makes it easy
to run multiple instances of CUWI from the same installation.

The configuration file is simply a file containing an anyonymous Perl
hash, in perl syntax (including comments etc.).

Note that the configuration file does not apply only to CUWI itself,
but can apply to its deploying middleware or Hypnotoad server. See
L</Deployment Options> and L</Configuring Hypnotoad>.

A minimal configuration file, setting the HTTP request root, working
directories and corpora registry path to default values, would look
like this:

  {
    registry => '/usr/local/share/cwb/registry:/usr/local/cwb/registry',
    var => '/var/cache/cuwi', # for cached frequency lists
    tmp => "/tmp",            # for export file downloads
    root => "cuwi",           # available under http://*/cuwi
  }

The following configuration file variables are meaningful for CUWI:

=over 4

=item C<registry>

Specifies the registry directory paths. See L</Registry Information>.

=item C<root>

Value: a string. Specfies the HTTP request root for the
application. Ie. if C<root> is set to C<cuwi>, all request paths must
start with C</cuwi> and thus a typical HTTP request will have an URL
such as L<http://localhost/cuwi/corpusname/search?query...>

Note that if you deploy CUWI behind a proxy, you should not change the
request path.

=item C<var>

Value: a string. Specifies the cache directory for frequency lists
etc. Recommended value: C<'/var/cache/cuwi'>. No default. Directory
must exist and be writable by the application.

=item C<tmp>

Value: a string. Specifies the temporary directory for export files.
Recommended value: C<'/tmp'>. No default. Directory must exist and be
writable by the application. Any files generated will be removed after
use.

=item C<appname>

Value: a string. Specifies the name of the application as used in log
fiels and messages. Default: 'cuwi'.

=item C<logdir>

Value: a string. Specifies the directory path for log files.
Recommended value: C<'/var/log'>. No default. Directory must exist and
be writable by the application. If a relative path is specified, it is
relative to the CUWI application home, which is the directory
C<CUWI.pm> resides in by default, but can be changed by setting the
C<MOJO_HOME> environment variable.

Note that the naming of the log files is different if you use this
configuration variable. By default, cuwi uses the Mojolicious
convention and writes log files only if a C<log/> subdirectory is
available in the application home. Log files have the name
'development' or 'production', depending on the current mode, and the
suffix C<.log>. If you set the L<logdir> configuration variable and it
points to an existing direcotry writable by the application, the value
of the C<appname> configuration variable is prepended to the name of
the log files. This makes it easier to use multiple instances that all
log into a common log directory.

If the directory is not writable (ie., you are trying to use
C</var/log>, which is only writable by root), CUWI will ignore your
setting and revert to the Mojolicious default convention.

It is recommended to create C</var/log/cuwi>, writable by the
production sytem user used by the application (as set in the
C<hypnotoad> section, for example), and set a different C<appname> for
each instance. When you use the development server under your
username, CUWI will ignore the setting and use the console or the
local C<log/> directory, if it exists and is writable.

=item C<appdir>

Value: a string or an array. Defaults to the current working
directory. The directory or directories specified will be searched for
C<static> or C<templates> subdirectories, and any files found there
have precedence over the ones supplied with CUWI. This is intended to
enable the administrator to copy and edit the existing files to
customize an instance of CUWI.

The default can be specified with the CUWI_HOME environemnt variable.

=item C<corpora>

Value: a hash. See L</Configuring corpora>.

=item C<OPTIONS>

Value: a hash. Additional options. See L</Additional Configuration
Options>.

=back

=head2 Registry Information

CUWI parses all the registry files found in the registry path (a comma
separated list of paths) using L<CWB::Model>. Additional information
is acquired using C<cwb-statistics> (if available) and by parsing the
corpus info files.

The registry can be specified in the configuration file with the
C<registry> entry. The value is again a comma separated list of
directories.

Note that CWB environment variable C<CORPUS_REGISTRY> can be used to
overrule the registry for C<CWB::Model>. C<CWB::Model> also ignores
emacs save files, backup files and similar, which my cause problems
for CWB tools. Be careful.

Errors encountered when parsing registry files and registry info files
will be written to standar output or the in the log directory, if a
C<log/> subdirectory is present. Corpora with errors in their files
will be dropped from the CUWI registry.

CUWI uses C<CWB::Model> to parse the registry files and uses all
declarations, including encoding and language. Defaults are UTF-8 and
US English. This might be confusing since CWB uses Latin-1 as the
default language, but is a better match for most modern corpora.

=head2 Corpus Info Files

Corpora have additional metadata in the info files as specified in
their registry description. By default, this is assumed to be a
description of the corpus with no formatting and in English.

If the description starts with an XML tag, it is assumed to be in HTML
and any markup is preserved.

Alternatively, the corpus info file can be in the CUWI multilingual
description format. In this case, the data is used for popups and
descriptions in the interface.

CUWU multilingual description format for corpus info files has the
following syntax:

 <FIELD> [attribute name] <language> <text>

The <NAME> field specifies a descriptive name for the corpus, and has
no attribute name.

Attribute descriptions are introduced with C<ATTRIBUTE> for postional
attributes and <STRUCTURE> for structural attributes, following the
standard CWB registry file syntax.

The <DESCRIPTION> field has a special syntax, since the langauge tag
is followed by multiple HTML lines until an empty line to allow longer
corpus descriptions.

See C<t/corpora/data/*/*.info> for examples.

=head2 Configuring Corpora

It is possible to supply a number of configuration options for
individual corpora and create virtual corpora, corpus groups etc.,
using the configuration file filed C<corpora>.

=head3 Changing Corpus Info

You can overrule any value for a corpus as specified in the registry
by declaring the new value under the C<corpora> configuration variable
(hash):

  {
    registry => '/usr/local/share/cwb/registry:/usr/local/cwb/registry',
    var => '/var/cache/cuwi', # for cached frequency lists
    tmp => "/tmp",            # for export file downloads
    root => "cuwi",           # available under http://*/cuwi
    corpora => {
      cuwi-fr => { encoding => 'iso_8859-1' }
    }
  }

*** Not tested in this version, possibly faulty. ***

=head3 Corpus groups

Corpus groups can be used to organize the presentation of the corpora
so that only the group is listed on the index page and the corpora in
the group can be accessed using the group index page, and to enable
the corpus peer facility where the search forms permit the user to
send the same query to another corpus in the same group.

This facility is intedned to support the cases where you need a common
interface for different similar corpora, for example to support a
project or working group.

Note that group names can not be identical to a lower-cased corpus
names, but are not restricted to lower case.

A single corpus can be a member of multiple groups, but such a set-up
can be confusing for users unless the corpus peer facility is
disabled, since members of all the groups will show-up as peers in the
search forms for such a corpus.

Corpus groups are configured with the C<GROUPS> configuration
variable. C<GROUPS> is a hash where group names are keys and values
are configuration hashes with the following members:

=item C<title>

Value: a hash where keys are langauge tags and values strings. Used
for the long title of the virtual corpus.

=item C<description>

Value: a hash where keys are langauge tags and values HTML description
strings. Used for the description of the virtual corpus.

=item C<members>

Value: an array of strings. Lists corpora (non-virtual or virtual) to
be included in the group by their lower-cased names.

=item C<nopeers>

Value: boolean. Default: C<0>. By default, all group members
become peer corpora of other members and will show up in search forms,
enabling the user to send a query to another member of the group. This
feature is enabled regardless of how you access the corpus. A true
value will disable this feature.

=item C<nobrowse>

Value: boolean. Default: C<1>. By default, all group members get the
C<nobrowse> flag, which prevents them to be listed on the CUWI index
page. In this way, groups members are only listed in the group
listing. Set C<nobrowse> to undef to disable this feature.

=item C<hidden>

Value: boolean. Default: C<0>. If set to a true value, the group
will not be listed on the index page. If you only use the group to get
the peer corpus feature, you should also set C<nobrowse> to a false
value.

=back

An example configuration file for a group:

  {
    registry => '/usr/local/share/cwb/registry:/usr/local/cwb/registry',
    var => '/var/cache/cuwi', # for cached frequency lists
    tmp => "/tmp",            # for export file downloads
    root => "cuwi",           # available under http://*/cuwi
    corpora => {
      GROUPS => {
        testing => {
          title => 'CUWI testing corpora',
          description =>
            '<p>This is a toy group, showing the <i>CUWI grouping facility</i>
            with a tiny corpus group made from CUWI testing corpora.</p>'
          nobrowse => 0, #show members also on index page
          members => [ "cuwi-sl", "cuwi-fr" ],
        }
      },
  }


=head3 Virtual Corpora

A virtual corpus is entirely created and cofigured form the config
file (or directly in your program using the L<CWB::Model> API), using
existing CWB-encoded corpora to perform actual queries. This mechanism
is intedned for those cases when you need to present a corpus with
different characteristics from those in the actual encoding or perform
queries on multiple corpora at the same time.

A virtual corpus is defined with an entry under the C<VIRTUALS>
configuration variable (a hash). The key is the lowercased name of the
new corpus, its value is a hash of cration options:

=over

=item C<title>

Value: a hash where keys are langauge tags and values strings. Used
for the long title of the virtual corpus.

=item C<description>

Value: a hash where keys are langauge tags and values HTML description
strings. Used for the description of the virtual corpus.

=item C<subcorpora>

Value: an array of strings. Lists non-virtual (file-based) corpora to
be included in the virtual corpus.

=item C<options>

Value: a hash of key/value pairs for coprus configuration options. The following options are supported:

=over 4

=item C<general_align>

Value: boolean. Only present an align option in the search form and
align with any aligned corpora when selected.

=item C<interleaved>

Value: boolean. Interleave results from all member copora on every page.

*** Only interleaved virutal corpus form is supported at this time,
    this option must be set. ***

=item C<classes>

Value: a hash. Keys must match the classnames array. Values are arrays
of lowercased names of member corpora to be used when a class is selected.

With this option, a virtual corpus presents the classes lists in the
search form, and when an option is selected, the search is only
performed on the subcorpora included in the class. This efectively
allows a virtual corpus to be used as a number of different composed
corpora.

=item C<classnames>

Value: array of strings. The list must mach the class declaration if
any of the two is used.

*** Warning: This is currently used so that the order of classes,
where the first is the default, can be specified, since a hash is used
for classes themselves. This variable is to be removed in a future
version since it duplicates information from C<classes>, and
C<classes> will be changed to be a list of pairs ***


=back

=back

A virtual corpus example, with frequencies and no-browse for members:

  {
    registry => '/usr/local/share/cwb/registry:/usr/local/cwb/registry',
    var => '/var/cache/cuwi', # for cached frequency lists
    tmp => "/tmp",            # for export file downloads
    root => "cuwi",           # available under http://*/cuwi
    corpora => {
      VIRTUALS => {
        cuwoos => {
          subcorpora => [ "cuwi-sl", "cuwi-fr" ],
          classnames => [ "both", "fr", "sl" ],
          classes => {
		      both =>
		        [ "cuwi-sl", "cuwi-fr" ]
		      fr => [ "cuwi-fr" ], sl => [ "cuwi-sl" ]
                     },
	  options => {
            interleaved => 1
	  }
        }
      }
    }
    OPTIONS => {
      "no_browse" => ["cuwi-fr", "cuwi-sl"],
      frequencies => ["cuwi-fr", "cuwi-sl"],
  }

=head3 Authentication

*** Warning: currently the authentication mechanism is somewhat
   limited, and passwords are stored in cleartext. ***

Access for a corpus can be limited to authenticated users. This is
declared under the L<AUTH> configuration variable in the C<corpus>
section of the configuration file. The value is a hash, where each
entry has lowercased corpus name for its key a has with authentication
options for its value.

Only one authentication option is available: the domain.

Domains are declared separately and for each domain a number of users
can be specified with their passwords in cleartext.

Note that authentication works using encrypted cookies.

Example:


  {
    registry => '/usr/local/share/cwb/registry:/usr/local/cwb/registry',
    var => '/var/cache/cuwi', # for cached frequency lists
    tmp => "/tmp",            # for export file downloads
    root => "cuwi",           # available under http://*/cuwi
    corpora => {
      AUTH => {
        "cuwi-fr" => {
           domain => "myproject"
        }
      }
    }
    DOMAINS=> {
      myproject => {
        user  => "password",
        frantz => "password123"
      }
    }
  }

=head2 Additional Configuration Options

Additional configuration options are set under the configuration
variable C<OPTIONS> in the corpora hash configuration variable.b They
include the following options:

=over 4

=item C<no_browse>

Value: an array of strings, containging lowercased corpus names. The
corpora specified will not be visible in the main listing of available
corpora. If any of the corpora is included in a corpus group, they
will be listed there.

=item C<frequencies>

Value: an array of strings, containging lowercased corpus names. CUWI
will try to generate frequenciy lists for these corpora if none are
availabe or if the existing frequency files are older than the corpus
data files. Links to the files will be displayed on the corpus info
page. The frequency files are stored in the cache directory specified
with the C<var> configuration variable, and frequency generation is
not attempted if no C<var> is specified.

=item C<maxfreq>

Value: integer. Limits the maximal size of frequency lists.

=item C<bigcontext>

Value: string or integer. Default: C<p>. Sets the default context for
a cpos (detailed match) view.

String values should be C<p>, C<s> or another structural tag. If the
structural tag is available in the current corpus, it will be used as
the context for the detailed match view. If not, C<p> and C<s> tags
will be tried, in this order.

Integer values are used as left and right token context. I.e. a value
of C<15> will display the match corpus position with 15 tokens before
and after the position.


=back

=head1 DEPLOYMENT

The recommended way to deploy CUWI is to run it with the stand-alone
production pre-forking web server Hypnotoad, possibly behind a proxy
web server.  This is the recommended deployment option which avoids
slow startups due to registry parsing and offers maximal pefromance.

However, many other options are available. For documentation and
examples, see L<Mojolicious::Guides::Cookbook/DEPLOYMENT>. Note that
CGI deployment is not recommended due to slow startup time.

=head2 Configuring Hypnotoad

Hypnotoad is a stand-alone preforking web server for Mojolicious. It
is easy to configure hypnotoad to run behind a proxy, for example
Apache HTTPD or NGINX.

  # start or hot-deploy and update
  $ hypnotoad cuwi
  
  # stop
  $ hypnotoad -s cuwi

Hypnotoad is configured with a hash under the configuration variable
'hypnotoad' in the config file. This is an example configuration for a
CUWI instance on port 3001, running 8 workers.

  {
    hypnotoad => {
      listen =>  ["http://*:3001"],
      workers =>  8
    },
    registry => '/usr/local/share/cwb/registry:/usr/local/cwb/registry',
    var => '/var/cache/cuwi', # for cached frequency lists
    tmp => "/tmp",            # for export file downloads
    root => "cuwi",           # available under http://*/cuwi
  }

Fore more information, try C<hypnotoad -help> and
L<Mojo::Server::Hypnotoad>, for details on configuration parameters
see L<Mojo::Server::Hypnotoad/SETTINGS>.

=head1 LOG FILES

CUWI uses Mojolicious infractructure for its log files. By default, it
will write its log files to the C<log/> directory in its application
home (the directory where CUWI.pm resides or C<MOJO_HOME>, if
specified).

If noC<log/> directory is available, the application will output log
info on the terminal, if available. (Not that Hypnotoad disconnects
server instances from terminal to run them in daemon mode, so no info
will be available in this case.)

The verbosity of the logging depends on the C<MOJO_MODE> mode, and can
be chaged with the C<MOJO_LOG_LEVEL>. In C<production> mode, CUWI logs
startup information, search requests and processing information. In
debugging mode, logs become somewhat verbose.

** Add info on how to change log file location. **

=head1 OPTIONAL DEPENDENCIES

CUWI will use L<Spreadsheet::Write> to enable exporting results in C<CSV> and
Excel formats.

L<Mojolicious> has a number of optional dependencies for additional
functionality, such as L<EV>, L<IO::Socket::IP>, L<IO::Socket::SSL>,
L<Net::Rendezvous::Publish> and L<Plack>.


=head1 AUTHORS

Jan Jona Javorsek <jona.javorsek@ijs.si>,
Tomaz Erjavec <tomaz.erjavec@ijs.si>

=head1 SEE ALSO

=over 4

=item *

CUWI Web users's Manual: L<CWB::CUWI::Manual>

=item *

Corpus Work-Bench: L<http://cwb.sourceforge.net>, L<CWB::CQP>

=item *

CUWI programming API: L<CWB::Model>

=item *

Mojolicious-base application: L<CWB::CUWI>

=item *

Mojolicious web framework: L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojoliciou.us/>

=back


