=head1 NAME

CUWI Manual - Corpus Users' Web Interface Manual

=head1 OVERVIEW

CUWI - Corpus Users's Web Interface, provides a web interface to the
Corpus Workbench Toolkit corpus encoding and query system (see:
L<http://cwb.sourceforge.net>). It presents forms to allow you to
specify your query, runs CWB binary command line tools (mostly CQP) in
the background and formats the results in HTML.

It is implemented with L<CWB::Model>, a perl binding to the CWB binary
commands, that can be used independently in your programs or on the
command line.

This document contains user documentation for the CUWI Web
interface. Please use L<CWB::CUWI::Administration> if you are
installing or setting up CUWI.

Please note that all the individual form entries can be documented
with tooltips, which can also document corpus-specific attributes (if
documentation is provided by the corpus info file) and can be
translated.

=head1 INTERFACES

CUWI has a modular structure, unified by the title bar controls and
navigation on the top of the page. At this time, it provides a number
of default views:

=over 4

=item * B<Index>

Index view shows the list of corpora or groups and, when you click on
a group, members of the selected group, for the registry or registries
on the system.

=item * B<Corpus info>

Corpus info page shows the description and some statistical inormation
of the selected corpus and allows you to start a search. You can
switch between the different search modes using the top bar.

Note that some copora in the system might be virtual corpora,
constructed from multiple CWB corpus objects, in which case a list of
member corpora will be presented.

=item * B<Query results>

After running a query, a query result interface with the form for the
query in question is presented. See L</Results> for more information.

=back

CUWI has two main searching interfaces: L</Simple Search> provides a
simple search form, and L</Advanced Search Options> gives the user a
chance to construct complex searches. In addition, you can use the CQP
query langauge directly (see L</Using the CQP Query Language>).

There may be othere interfaces available, and a plug-in infrastructure
is in the works. We hope to provide a web interface for most anything
you could to with the CWB tools, and more.

=head1 SEARCH BASICS

CUWI expects the search query to contain simple words with optional
C<< ? >> and C<< * >> place-holders for any character or any sequence of characters, respectively.

You can separate alternatives with C<< | >> and use C<< [] >> for 'any
token'.

In addition, you can use the fully power of the CQP query langauge
simply by enclosing the query for a word in brackets (C<< [ ]
>>). CUWI does not care, since the simple queries are converted to CQP
automatically. The conversion is influenced by the rest of the search
form; in the simple search, all searches will be performed on several
predefined positional attributes ('word' and 'lemma' by default) to
give you the maximum versatility with minimum hassle. In the advanced
search mode, the 'Search' attributes bellow the search form are used
to select the positional attribute of the token to search on.

These queries are identical when 'word' is the selected positional
attribute:

 word?
 ["word."]
 [word="word."]

The search result page will display how search query was transformed
into a CQP query, and you can click on the CQP query to edit it
further. If CQP syntax (triggered by any use of quoting in the search
query) is detected, no conversion is applied to the tokens in question
and the 'Search' attributes are ignored for that term.

If you want full CQP syntax for the whole query, preceede the query
with C<< + >> followed by a space to disable all processing. See
L<CQP Tutorial|http://cwb.sourceforge.net/files/CQP_Tutorial/> for
more info.

When using the advanced search interface, you should pay attention to
the following important options in the search form:

=over 4

=item * B<Corpus>

The C<Corpus> drop-down menu appears to the right of the search query
field when you are working with a group of corpora. If you select a
different member of the group (a "peer corpus"), the search will be
redirected to that corpus.

=item * B<Within>

C<Within> represents a search constraint and allows you to constraint
the whole match within a selected structural argument. With this
option, you can prevent your matches to span sentence boundaries, for
example (the default).

Note that this feature modifies the CQP query and will result in a
warning if you request an unparsed CQP query with the C<< + >> escape.

=item * B<Ignore>

C<Ignore> allows you to ignore case differences and diacritic
marks. Note that the latter can be problematic with anthing but the
Latin-1 encoding due to CWB limitations.

=back

See L</Advanced Search Options> for the other search options.


=head2 Results

The results are by default represented in the KWIC (Keyword in
Context) format, which is essentially a table of results, aligned on
the matching token. CUWI allows you to customize the result
representation in a number of ways:

=over 4

=item * B<Show>

C<Show> allows you to specify which token annotations (positional
attributes) will be displayed. You can even search by one attribute
(i.e. C<lemma>) and not display it (by selection C<word> and C<pos>,
for example). When multiple attributes are selected to be displayed,
they will be arrangend in a vertical stack and colored differently.

=item * B<Align>

C<Align> option declares that one or multiple (or even all, when no
options are present) aligned corpora segments are to be displayed
along with the results. Note that this option will only appear if
there are aligned corpora in the system registry for the current
corpus.

=item * B<Contex tokens>

C<Context tokens> allows you to specify the amount of context to be
displayed in the KWIC format. This sets both the left and the right
context, not counting the match token(s).

=item * B<Display mode>

C<Display mode> sets the way your results are presented to
you.

Besides the default C<KWIC> mode, you can select C<Sentences> and, if
annotation for paragraphs is available, also C<Paragraphs>. These two
modes display the results as flowing text, with multiple interleaving
lines when mulitple attributes are being displayed. Any aligned text
will be shown next to the results if so desired.

C<Wordlist> display mode constructs a frequency list from the result
matches and (which is a time-consuming operation and can be long on
large result sets) and provides you with links from frequencies to the
actual matches. See also L</WORDLISTS>.

=item * B<Include tags>

C<Include tags>, when set, enables the display of structural
attributes as XML tags (with attributes). Please not that some
attributes may not be displayed (by default, these are C<seg>,
C<align>, C<text>, C<corpus>). This can be controlled in the CUWI
configuration file, see L<CWB::CUWI::Administration/Additional
Configuration Options>.

When C<Wordlist> display mode is selected, structural attributes are
taken into account wiht the frequency count and with the context
search links.

In the detailed display for a match (link from the match number),
structural attributes are included automatically.

=item * B<Listing mode>

C<Listing mode> specifies wheather you wish to page througt the whole
result set or, alternatively, see a random sample of the results. The
latter is advisable when looking at linguistic texts from multiple
sources to avoid first-in-corpus bias.

=item * B<Results per page>

C<Results per page> controls the number of mathes to be displayed per
page or the sice of the random sample.

=item * B<Sort>

C<Sort> allows you to control the order of presentation. By default,
the C<order> sort target is selected and the results are sorted by
their order in the corpus (aka C<cpos>). You can select sorting by the
matched token(s) or their left or right context.

Secondly, you can select the attribute to be used for the sorting
(ignored for C<cpos>).

And last, you can select the sort order (ascending/descending) and
sort direction (natural/reversed). Reversed order will sort from the
back of the selected sort target.

=back

=head2 Simple Search

Simple search interface is inteded for users who need to use the
corpus query interface without going into the details of the advanced
search possibilities.

The simple search interface allows the use of the standard C<< ? >>
and C<< * >> place-holders for any character or any sequence of
characters, respectively, and also permits the use of C<< | >> to
separate alternatives and C<< [] >> for 'any token', but gives no
other options. Instead, it runs the search on several positional
attributes (C<word> and C<lemma> by default, configurable per corpus
in CUWI configuration file).

If you need to further constraint you results, you can click on the
CQP query on the result page to access the same query in the advanced
search form.

=head2 Advanced Search Options

There are several more involved search options available in the
advanced search interface.

=over 4

=item * B<Only where>

C<Only where> is a constraint on structural attributues. Only mathes
where the selected attribute value on the match tokens matches the
specified search pattern will be returned. This can be used, for
example, to limit your search to a specific author or translator if
such metadata information is incoded in the structural attributes, or
construct lingustic constraints if you corpus contains syntactic
annotations in structural attributes.

Note that this feature modifies the CQP query and will result in a
warning if you request an unparsed CQP query with the C<< + >> escape.

=item * B<Aligned constraint>

C<If/Unless aligned ... matches> allows you to specify a secondary CQP
query to run on the selected aligned segment of an aligned corpus and
filter results accordingly. Note that the whole aligned segment is
used in the search. This feature can be used for example to exclude
examples with certain translations indicating one of the meanings of
an expression.

=back

=head2 Using the CQP Query Language

In addition to the simple query metacharacters, all the power of the
CQP query language can be used when constructing searches with
CUWI. Please see the See
L<CQP Tutorial|http://cwb.sourceforge.net/files/CQP_Tutorial/> for
more info on the language itself.

In the query interface, you can also look at a number of examples by
clicking on the C<Query> label on the left of the field, which will
display a rather big tooltip with a number of query examples in the
simple form and in CQP syntax.

=head1 WORDLISTS

Word lists or, more accurately, frequency lists, can be generated
simply by selecting the C<Wordlist> display option.

Note that frequency list generation can be slow. In addtion, you can
set up CUWI to pre-generate frequency lists for whole corpora using
the CUWI configuration file. Such frequency lists then become
available as text files in the corpus info page.

=head1 EXPORTING RESULTS

CUWI offers multiple exporting options on the title bar of its result
pages. Currently, the supported formats are Perl (a dump of the result
object, usable from a perl script), JSON (L<http://www.json.org>), XLS
(Microsoft Excel Worksheet) and CSV (Comma Separated Values, a generic
tabular format).

Please see the L<Administration Manual|CWB::CUWI::Administration> and
install any optional dependencies if you can't see a format you
require.

When exporting results, consider that all the result set will be
exported, not just the current page, so avoid exporting very large
results sets to avoid timeout errors.

=head1 AUTHORS

Jan Jona Javorsek <jona.javorsek@ijs.si>,
Tomaz Erjavec <tomaz.erjavec@ijs.si>

=head1 SEE ALSO

=over 4

=item *

Configuration and Administration L<CWB::CUWI::Administration>

=item *

Corpus Work-Bench: L<http://cwb.sourceforge.net>, L<CWB::CQP>

=item *

CUWI programming API: L<CWB::Model>

=item *

Mojolicious-base application: L<CWB::CUWI>

=item *

Mojolicious web framework: L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojoliciou.us/>

=back
