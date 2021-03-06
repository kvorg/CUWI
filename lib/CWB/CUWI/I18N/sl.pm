package CWB::CUWI::I18N::sl;
use base 'CWB::CUWI::I18N';
use utf8;

#sub new { return };
our %Lexicon =
  (

   thousands_sep => '.',
   decimal_sep => ',',

   # layouts/main.html.ep
   'CUWI Search' => 'Iskalnik CUWI',
   'Logged in as' => 'Uporabnik',
   Languages => 'Jezik',
   langtag => 'Slovensko', # preferred name for this language, in the language
   Logout => 'Odjavi',
   Help => 'Pomoč',
   'Advanced search' => 'Zahtevno iskanje',
   'Simple search' =>  'Preprosto iskanje',

   # index.html.ep
   blurb => <<"FNORD",

<p>CUWI (Corpus Users' Web interface) je pregledovalnik in iskalnik za
korpuse, zapisane v sistemu <a href="http://cwb.sourceforge.net/">IMS
Open Corpus Workbench</a>.  Več o iskalniku CUWI najdete v <a
href="[_1]">navodilih</a>.</p>

<p>Spodaj najdete seznam korpusov, ki so na voljo na tem
strežniku. Več podatkov o posameznem korpusu boste dobili, ko ga
izberete v seznamu. Upoštevajte, da nekateri korpusi niso na voljo za
javno uporabo.</p>

<p>Dokumentacijo posameznih funkcij iskalnega vmesnika lahko dobite s
klikom na ime polja. V splošnem lahko uporabljate preprosti način
iskanja (z znakoma <code>?</code> in <code>*</code> za poljubni znak
in več poljubnih znakov) ali pa uporabite <a
href="http://cwb.sourceforge.net/files/CQP_Tutorial/">poizvedovalni
jezik CQP</a>, ki doupušča bolj zapletena poizvedovanja.</p>
FNORD

   'Available Corpora' => 'Izbor korpusov',
   Statistics => 'Statistični podatki',
   'Number of corpora' => 'Število korpusov',
   'Total size (tokens)' => 'Skupno število besed',
   'Total size (disk)' => 'Skupna velikost na disku',
   Languages => 'jeziki',
   Encodings => 'kodiranja',

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
   'Size' => 'Velikost',
   'Positional attributes' => 'Pozicijski atributi',
   'Structural attributes' => 'Strukturni atributi',
   'Alignment attributes' => 'Poravnave',
   'attributes' => 'atributov',
   'types' => 'različnih',
   'tokens' => 'besed',
   'regions' => 'območij',
   'alignment blocks' => 'poravnanih segmentov',
   'frequencies' => 'frekvenčni seznam',

   # corpus.html.ep
   'No matches for query ' => 'Ni zadetkov za poizvedovanje ',

   # form_simple.html.ep
   'Simple query' => 'Preprosto iskanje',

   # form.html.ep
   'Query' => 'Poizvedba',
   ttip_query => <<FNORD,

Iskalna poizvedba je lahko sestavljena iz preprostih besed (pojavnic),
ki pa lahko vsebujejo tudi znaka <code>?</code> in <code>*</code>
namesto enega ali poljubno poljbunih znakov. Posamezna celotna beseda
ima lahko navedene tudi alternative, ki so med seboj ločene z
<code>|</code>. Oznaka ~[~] pomeni 'katero koli pojavnico'.<br />To
poizvedbo bo sistem prevedel v poizvedovalni jezik CQP. Spodaj v
rubriki 'Išči' lahko izberete tipe oznak, ki naj bodo vključeni v
poizvedovanje. Na strani z rezultati poizvedbe bo prikazan zapis v
jeziku CQP, ki ga lahko uporabite kot povezavo in prilagodite za
zahtevnejše poizvedbe. Če sistem zazna, da je poizvedba že v formatu
CQP (ki v poizvedbi zahteva navednice), poizvedbe za posamezno besedo
(pojavnico) ne pretvarja in tudi ne uporablja izbranih oznak v rubriki
'Išči'.<br />Ubežna sekvenca <code>+ </code> (znak za seštevanje in
presledek) na začetku poizvedbe izključi pretvorbe za celotno
poizvedbo, da lahko prosto uporabljate jezik CQP. Uvodni napotki za
CQP: <a href="http://cwb.sourceforge.net/files/CQP_Tutorial/">CQP
Tutorial</a>.<br />

<h4>Primeri poizvedb za pozicijski atribut <code>word</code> (pojavnica)</h4>
<table class="examples">
<tr><th>Preprost način</th><th>CQP</th><th>Razlaga</th></tr>
<tr><td>where</td><td>~[word="where"~]</td><td class="t">posamezne instance pojavnice 'where'</td></tr>
<tr><td>wher*</td><td>~[word="wher.*"~]</td><td class="t">pojavnice, ki se začno na 'wher'</td></tr>
<tr><td>wh*e</td><td>~[word="wh.*e"~]</td><td class="t">pojavnice na 'wh' s koncem na 'e'</td></tr>
<tr><td>wh?</td><td>~[word="wh."~]</td><td class="t">pojavnice s 3 črkami na 'wh'</td></tr>
<tr><td>who|what|whom</td><td>~[word="who|what|whom"~]</td><td class="t">ena od pojavnic 'who', 'what', 'whom'</td></tr>
<tr><td>who|what has</td><td>~[word="who|what"~] ~[word="has"~]</td><td class="t">zaporedja, kjer 'who' ali 'what' sledi 'has'</td></tr>
<tr><td>and ~[~] has</td><td>~[word="and"~] ~[~] ~[word="has"~]</td><td class="t">zaporedja 'and' in 'has', med katerima je ena beseda</td></tr>
<tr><td>and ~[~]{0,3} has</td><td>~[word="and"~] ~[~]{0,3} ~[word="has"~]</td><td class="t">zaporedja 'and' in 'has', med katerima je od 0 do 3 besede</td></tr>
<tr><td>&lt;s&gt; I</td><td>&lt;s&gt; ~[word="I"~]</td><td class="t">pojavnice "I" na začetku povedi</td></tr>
</table>
<h4>Zahtevni primeri v CQP</h4>
<table class="examples">
<tr><th>CQP</th><th>Razlaga</th></tr>
<tr><td>~[word=".*ies" & lemma=".*y"~]</td><td class="t">besede s koncem pojavnice na 'ies' in leme na 'y'</td></tr>
<tr><td>~[word=".*ies" & lemma!=".*y"~]</td><td class="t">besede s koncem pojavnice na 'ies' in lemo, ki se <b>ne></b> konča na 'y'</td></tr>
<tr><td>~[word="...*a" | lemma=".*um"~]</td><td class="t">3 ali več črk dolge besede s koncem na 'a' ali z lemoa, ki se konča na 'um'</td></tr>
<tr><td>~[word="interest|interested"~]</td><td class="t">pojavnica 'interest' ali pojavnica 'interested'</td></tr>
<tr><td>~[word="interest(s|(ed|ing)(ly)?)?"~]</td><td class="t">interest, interests, interested, interesting, interestedly, interestingly</td></tr>
<tr><td>~[word="wh.+" & lemma!=word~]</td><td class="t">besede s pojavnico, ki ima 3 črke ali več in se začne na 'wh', vendar pojavnica in lema nista enaki</td></tr>
<tr><td>~[(lemma="go") & !(word="went"%c | word="gone"%c)~]</td><td class="t">besede z lemo 'go', razen besed s pojavnico 'went' ali 'gone', ne glede na velike ali male črke</td></tr>
<tr><td>~[(lemma="go") & word!="went|gone"%c~]</td><td class="t">isto v bolj zgoščenem zapisu</td></tr>
</table>
FNORD
   ttip_simple_query => <<FNORD,

Vnesite preprosto iskalno zaporedje.<br />
Primeri: <code>beseda ka*koli
m. "~[Rr~]egexp?" [] on|ona|ono</code><br />
Iskalno zaporedje je sestavljeno iz ene ali več besed, ki jih ločijo
presledki. Iskalnik bo iskal brez razlikovanja velikih in malih črt in
bo iskal hkrati po pojavnici (zapisu besede v korpusu) in lemi
(slovnično nevtralni obliki)<br />
V zapisu besede lahko uporabite znak <code>?</code> za poljuben znak in 
znak <code>*</code> za poljubno zaporedje (tudi nič) znakov.<br />
Alternativne besede lahko navedete tako, da jih ločite z znakom <code>|</code>,
npr. <code>on|ona|ono</code>.<br />

Poleg tega lahko uporabite <code>~[~]</code> kot znak za poljubno besedo ter z oznakami XML (npr. <code>&lt;s&gt;</code> za poved) označite meje strukturnih atributov v korpusu.<br />
Če besedo zaprete v navednice, vključite <a
href="href="http://cwb.sourceforge.net/files/CQP_Tutorial/">sintakso
CQP</a> in izključite pomagala iskalnika za to besedo. Če uporabite
poizvedbo CQP med znakoma <code>~[~]</code>, za to besedo veljajo pravila za
zahtevno iskanje.<br />
Zahtevno iskanje lahko vkljčite s povezave na meniju ali povezavo na zapis iskanja v jeziku CQP.
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

   'Include tags' => 'Vključi oznake',
   'Include Tags' => 'Vključi oznake',
   ttip_include_tags => <<FNORD,
Vključi strukturne oznake in njihove atribute v obliki oznak XML.<br />
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
   'Results per page' => 'Zadetkov na stran',
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
   shuffle => 'naključno',
   order => 'po vrsti',
   match => 'zadetek',
   left => 'levo',
   right => 'desno',
   ascending => 'naraščajoče',
   descending => 'padajoče',
   natural => 'navadno',
   reversed => 'a tergo',

   Reshuffle => 'Premešaj',

   #nav.html.ep
   'Prev' => 'Nazaj',
   'Next' => 'Naprej',

   #search_exports.ep
      'Export results' => 'Izvoz zadetkov',

   #search_{kwic,text,wordlist}.html.ep, cpos.html.ep
   'result_msg_sample_retrieved_for' =>
   'Naključni vzorec <b>[_1]</b> od skupaj <b>[_2]</b> zadetkov za poizvedovanje ',
   'result_msg_matches_x_to_y_retrieved_for' =>
   'Zadetki <b>[_1]</b> do <b>[_2]</b> od skupno <b>[_3]</b> zadetkov za poizvedovanje ',
   'result_msg_x_matches_retrieved_for' =>
   '<b>[_1]</b> zadetkov za poizvedovanje ',
   'result_msg_wordlist_sample x_out_of_y_distinct_from_z_for' =>
   'Vzorec <b>[_1]</b> zadetkov izmed <b>[_2]</b> različnih zadetkov od skupno <b>[_3]</b> zadetkov za poizvedovanje ',
   'result_msg_wordlist_x_distinct_out_of_y_for' =>
   '<b>[_1]</b> različnih zadetkov izmed <b>[_2]</b> zadetkov za poizvedovanje ',
   'result_msg_x_detailes_for_cpos' =>
   'Podrobni prikaz korpusnega položaja <b>[_1]</b> iz poizvedovanja ',
   'result_msg_in_x_seconds' => ' v [_1] s.',
   'Alignment to ' => 'Poravnava: ',

   #search_wordlist.html.ep - results
   TOTAL => 'VSEH',

   #search_{kwic,text}.html.ep - results
   'Structural Info' => 'Strukturni podatki',
   'Click result number for detailed view.' =>
   'Kliknite na številko zadetka za podrobni pogled.',
  );
1;
