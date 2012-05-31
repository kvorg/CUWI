package CWB::CUWI::I18N::sl;
use base 'CWB::CUWI::I18N';
use utf8;

#sub new { return };
our %Lexicon =
  (
   # layouts/main.html.ep
   'CUWI Search' => 'Iskalnik CUWI',
   'Logged in as' => 'Uporabnik',
   Languages => 'Jezik',
   langtag => 'Slovensko', # preferred name for this language, in the language
   Logout => 'Odjavi',
   Help => 'Pomoč',

   # login.html.ep
   Login => 'Prijava',
   Username => 'Uporabniško ime',
   Password => 'Geslo',

   # corpus.html.ep
   'Physical Properties' => 'Fizične lastnosti',
   Language => 'jezik',
   Encoding => 'kodiranje',
   'File size' => 'velikost datotek',
   'Attribute Descriptions' => 'Opis pozicijskih atributov',
   'Structural Attribute Descriptions (Tags)' => 'Opis stukturnih atributov',
   'Peer Corpora' => 'Korpusi v skupini',
   Statistics => 'Statistični podatki',
   'Size (tokens)' => 'Velikost (število besed)',
   'Positional attributes' => 'Pozicijski atributi',
   'Structural attributes' => 'Strukturni atributi',
   'Alignment attributes' => 'Poravnave',
   'attributes' => 'atributov',
   'types' => 'različnih',
   'regions' => 'območij',
   'alignment blocks' => 'poravnanih segmentov',

   # corpus.html.ep
   'No matches for query ' => 'Ni zadetkov za poizvedovanje ',

   # form.html.ep
   'Query' => 'Poizvedba',
   ttip_query => <<FNORD,
The search query can contain simple words with optional ? and *
place-holders. Your query will be converted into a CQP langauge query,
using the 'Search' attributes bellow. The search result page will
display how the simple search is transformed into a CQP query. If CQP
syntax (triggered by any use of quoting in the search query) is
detected, no conversion is applied and the 'Search' attributes are
ignored for that term. If you want full CQP syntax for the whole
query, preceede the query with + followed by a space.",
FNORD
   'Corpus' => 'Korpus',
   ttip_corpus_group => <<FNORD,
In a corpus group, you can send the search to a different corpus in
the group by selecting the name of the corpus here. Corpus groups can
be configured in the CUWI config file or by stating 'peers' in the
corpus info file.
FNORD
   Subcorpora => 'Podkorpusi',
   ttip_subcorpora => <<FNORD,
In a virtual corpus, you can select a subclass of subcorpora
here. Virtual corpora and subcorpus classes can be configured in the
CUWI config file.
FNORD
   'Search' => 'Išči',
   'Search Attributes' => 'Iskanje po pozicijskih atributih',
   ttip_search_attributes => <<FNORD,
Select the attribute to search on. If you need to search on different
attributes in the same query, you will have to use the CQP
syntax. When using CQP syntax, the selected Search attribute is used
as the default search. The attributes are extracted from the corpus
description in the corpus registry (so possibly some are less useful
then others).
FNORD
   'Within' => 'Znotraj',
   ttip_within => <<FNORD,
Constraint to keep the whole match inside a structural field, such as
a sentence or paragraph. 's' is the default since it is useful for
linguistic queries.
FNORD
   'Ignore' => 'Ignoriraj',
   'case' => 'velike črke',
   'diacritics' => 'naglasna znamenja',
   'Only where' => 'Le če',
   'Structural Constraint' => 'Pogoj strukturnega atributa',
   'matches' => 'ustreza',
   'Structural Constraint Query' => 'Iskanje po strukturnem atributu',
   'If' => 'Če',
   'Unless' => 'Razen če',
   ttip_struct_constraint => <<FNORD,
Requires the match to be inside a structural region (xml tag) with the
selected attribute matching the constraint. Can be used for selection
of a specific text, author or part of speech, depending on corpus
markup.
FNORD
   'aligned' => 'poravnava',
   ttip_struct_query => <<FNORD,
Single term query to match structural attribute (XML attribute)
value. Rules for treatment of a single CQP regexp (without []) apply,
since structural attributes are not corpus tokens and do not have
positional attributes.
FNORD
   'Alignment Constraint' => 'Pogoj poravnave',
   ttip_align_constraint => <<FNORD,
Requires the aligned region to match (or, alternatively, not match)
the constraint. Can be used for excluding unwanted matches based on
alignment information. (Regardless if alignment is shown.) Option '*'
will apply to any existing alignemed corpora. Note that aligned
regions are often wider than the selected context.
FNORD
   'Alignment Constraint Query' => 'Iskanje po poravnanem segmentu',
   ttip_align_query => <<FNORD,
Full query to the match algined region in the selected aligned
corpus. Rules for treatment are the same as for the main query,
including the selected search attribute. Note that this might fail if
a search attribute is selected that does not exist in the aligned
coprus (CWB exception). Use CQP syntax in such cases.
FNORD
   'Show' => 'Izpiši',
   ttip_show => <<FNORD,
Select which attributes are to be displayed with your search
results. If multiple attributes are selected, they will be aligned
horizontally and displayed in different colors. The attributes are
extracted from the corpus description in the corpus registry (so
possibly some are less useful then others). In wordlist mode, the
attributes shown are used as part of the tuple for comparison.
FNORD
   'Align' => 'Poravnave',
   'Aligns' => 'Poravnave',
   'Alignments' => 'Poravnave',
   ttip_align => <<FNORD,
Display any available alignements. This interface can be enabled as an
alternative to individual alignment selections with the option
'general_align' in the CUWI configuration file. It is suitably mostly
for virtual corpora where subcorpora have different alignments.
FNORD
   ttip_aligns => <<FNORD,
Display aligned regions from selected aligned corpora with match
results from your query.. Note that aligned regions are often wider
than selected context.
FNORD
   'Context tokens' => 'Kontekst pojavnic',
   ttip_context_tokens => <<FNORD,
Set the number or left and right tokens (words) to be displayed in KWIC
(keyword in contex) display mode. Note that punctuation marks also
count as tokens.
FNORD

   'Display mode' => 'Način prikaza',
   'Display Mode' => 'Način prikaza',
   ttip_display_mode => <<FNORD,
Selects the display mode used to display the results.<br />

<b>KWIC</b> (keyword in context) displays the results as a table, with
the hit in the middle and the selected number of tokens on both
sides.<br />

<b>Sentences</b> mode displays the whole sentence, as marked in the
corpus, for each hit.<br />

<b>Paragraphs</b> does the same for paragraphs. Both modes are only
available if structural attributes to support them are present in the
corpus.<br />

<b>Wordlist</b> tabulates the hits and shows the number of occurencies
for each hit - to be used with wildcards (\'?\' and \'*\') i.e. to
find different word forms occurances. Note that multiple tokens and
multiple attributes can be used.
FNORD

   'Listing mode' => 'Način izpisa',
   'Listing Mode' => 'Način izpisa',
   ttip_listing_mode => <<FNORD,
<b>Sample</b> displays a random sample of hits ('reduce' in CQP). Hit
reload to see a different sample. <b>All</b> lists all the hits by
result page.<br />

In Wordlist display mode, <b>Sample</b> only uses the selected sample
to produce a frequeny list whereas <b>All</b> extracts the whole
result set to produce the frequency list (possibly a time-consuming operation).
FNORD
   'Results' => 'Zadetkov',
   ttip_results => <<FNORD,
Sets the number or results in the random sample or per page when all
the results are being listed.
FNORD
   'Sort' => 'Uredi',
   'Sorting' => 'Urejanje rezultatov',
   ttip_sort => <<FNORD,
Select a sort criterium: you can select:<br />
<b>position</b> (match, left - preceeding token and right - following
token),<br />
<b>content</b> (word or any other positional attribute),<br />
<b>order</b> (ascending, descending) and<br />
<b>direction</b> (natural - from the start or reversed - from the end of the token).
FNORD
   'Run Query' => ' Iskanje ',

   #form.html.ep - select menus
   If => 'Kjer',
   Unless => 'Razen kjer',
   paragraphs => 'odstavki',
   sentences => 'stavki',
   wordlist => 'besedni seznam',
   sample => 'vzorec',
   all => 'vse',
   order => 'po vrsti',
   match => 'zadetek',
   left => 'levo',
   right => 'desno',
   ascending => 'naraščajoče',
   descending => 'padajoče',
   natural => 'navadno',
   reversed => 'a tergo',

   #nav.html.ep
   'Prev' => 'Nazaj',
   'Next' => 'Naprej',

   #search_exports.ep
      'Export results' => 'Izvoz zadetkov',

   #search_{kwic,text,wordlist}.html.ep
   'result_msg_sample_retrieved_for' =>
   'Naključni vzorec <b>[_1]</b> od skupaj <b>[_2]</b> zadetkov za poizvedovanje ',
   'result_msg_matches_x_to_y_retrieved_for' =>
   'Zadetki <b>[_1]</b> do <b>[_2]</b> od skupno <b>[_3]</b> zadetkov za poizvedovanje ',
   'result_msg_x_matches_retrieved_for' =>
   '<b>[_1]</b> zadetkov za poizvedovanje ',
   'result_msg_wordlist_sample x_out_of_y_distinct_from_z_for' =>
   'Vzorec <b>[_1]</b> zadetkov izmed <b>[_2]</b> različnih zadetkov od skupno <b>[_3]</b> zadetkov za poizvedovanje ',
   'result_msg_wordlist_x_distinct_out of_y' =>
   '<b>[_1]</b> različnih zadetkov izmed <b>[_2]</b> zadetki za poizvedovanje ',
   'result_msg_in_x_seconds' => ' v [_1] s.',

   #search_wordlist.html.ep - results
   TOTAL => 'VSEH',

   #search_{kwic,text}.html.ep - results
   'Structural Info' => 'Strukturni podatki',
   'Click result number for detailed view.' =>
   'Kliknite na številko zadetka za podrobni pogled.',
  );
1;
