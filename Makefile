URL = ftp://ftp.ebi.ac.uk/pub/databases/interpro

all: iprgo.obo ipr-core.obo domo.obo merged.obo unmatched.txt

## ----------------------------------------
## InterPro-derived Ontology
## ----------------------------------------

ParentChildTreeFile.txt:
	wget $(URL)/ParentChildTreeFile.txt
.PRECIOUS: ParentChildTreeFile.txt

short_names.dat:
	wget $(URL)/$@

interpro.xml.gz:
	wget $(URL)/$@
.PRECIOUS: interpro.xml.gz
interpro.xml: interpro.xml.gz
	gzip -dc $< > $@.tmp && mv $@.tmp $@

ipr-names.tbl: interpro.xml
	xmlstarlet sel -t -m "//interpro" -v '@id' -o " " -v '@short_name' -o " " -v @type --nl $< > $@
ipr-names.obo: ipr-all.tbl
	./iprtbl2obo.pl $< > $@

# all of interpro in tabular format
ipr-all.tbl: interpro.xml
	xmlstarlet sel -t -m "//interpro" -v '@id' -o "|" -v '@short_name' -o "|" -v 'name' -o "|" -v @type --nl $< > $@

# ipr-core is just the portion of InterPro that is part of the interpro hierarchy
ipr-core.obo:  ParentChildTreeFile.txt
	 ./ipr-parent-child-to-obo.pl ParentChildTreeFile.txt > $@.tmp && mv $@.tmp $@

## ----------------------------------------
## GO-derived Ontology of domains
## ----------------------------------------

# IDspace: IPRGO
#  shadows the GO ID - each IPRGO ID is the implicit domain in GO

GO_XP_PRO = ../../ontology/extensions/x-mf-protein.obo

# protein binding node
PB = GO:0005515

# iprgo-core.obo - IPRs classified under IPRGO (GO-derived domains and families)
#
# we use Marijn's file as a bridge between the GO-derived ontology and IPR;
# each link is an is_a
iprgo-core.obo:  interpro_binding_edited.txt 
	./mapping2ont.pl $< > $@.tmp && mv $@.tmp $@

# go-binding-subset.obo - subset of GO under PB
#
# make a subset of GO with just descendants of GO:0019904 ! protein domain specific binding
# (note this whole procedure works for larger subsets - e.g. using 'RNA polymerase binding' to make 'RNA polymerase' is_a enzyme
#go-domain-binding-subset.obo:
#	blip ontol-query -r go -query "subclassT(ID,'GO:0019904')" -to obo > $@
go-binding-subset.obo:
	blip ontol-query -r go -i $(GO_XP_PRO) -query "subclassT(ID,'$(PB)'),\+genus(ID,_) " -to obo > $@.tmp && obo-grep.pl -r 'name: .* binding'  $@.tmp > $@
#	blip ontol-query -r go -query "subclassT(ID,'$(PB)') " -to obo > $@.tmp && obo-grep.pl -r 'name: .* binding'  $@.tmp > $@
#	blip ontol-query -r go -query "subclassT(ID,'$(PB)'),\+ (( subclassT(ID,X),subclass(X,'GO:0005488'),X\=$(PB))) " -to obo > $@.tmp && obo-grep.pl -r 'name: .* binding'  $@.tmp > $@


# iprgo-derived.obo - shadow of GO PB hierarchy; extract implicit protein hierarchy
#
# E.g.
#   X binding
#     Y binding
#
# ==> X is_a Y
#
# Also uses IPR IDs in the definition to generate equivalence axioms; e.g. GO:0097162 MADS box domain binding has def xref InterPro:IPR002100
iprgo-derived.obo: go-binding-subset.obo
	./go2ipr.pl $< > $@


## --
## next we combine ontologies and remove redundant edges
## --

# Ontologies to be combined
IN = header.obo ipr-core.obo iprgo-core.obo iprgo-derived.obo ipr-names.obo

# InterPro IDs take priority when merging
# (merges generally result from definition xrefs in GO)
MERGE = --merge-equivalence-sets -s IPRGO 1 -s IPR 10 -l IPRGO 9 -l IPR 2

iprgo-stage1.owl: $(IN)
	owltools $(IN) --merge-support-ontologies --reasoner elk $(MERGE)  --assert-inferred-subclass-axioms --markIsInferred -o $@

iprgo-stage1.obo: iprgo-stage1.owl
	owltools $< -o -f obo --no-check $@

# only use names and exact syns
iprgo-stage1-strict.obo: iprgo-stage1.obo
	egrep -v '(NARROW|RELATED|BROAD)' $< > $@

## ----------------------------------------
## Merging the two ontologies
## ----------------------------------------
# here we perform a more aggressive merge based on text matching

# pairs matches using entity recognition
#
# note: we currently use the strict file (EXACT syns and labels only)
matches-labeled.txt: iprgo-stage1-strict.obo
	blip-findall -u metadata_nlp -consult ignore.pro -i $< -goal index_entity_pair_label_match "entity_pair_label_reciprocal_best_intermatch(X,Y,S)" -no_pred -label -use_tabs  | sort -u > $@.tmp && mv $@.tmp $@
matches.txt: matches-labeled.txt
	cut -f1,3 $<  > $@

# translate pairs into OWL equivalence axioms
matches.owl: matches.txt
	owltools --create-ontology test --parse-tsv -a EquivalentClasses $< -o $@

# iprgo - the almost final product
#
# note this includes *all* of interpro (plus any IPRGO groupings), perhaps around 26k classes
iprgo.owl: iprgo-stage1.owl matches.owl
	owltools $< matches.owl --merge-support-ontologies --reasoner elk $(MERGE) --assert-inferred-subclass-axioms --markIsInferred -o $@
iprgo.obo: iprgo.owl
	owltools $< -o -f obo --no-check $@

# domo - final product; no orphans
#
# Remove all orphan interpros
domo.obo: iprgo.obo
	obo-grep.pl -r '(is_a|IPR:000000)' $< | grep -v ^owl-axiom > $@.tmp && mv $@.tmp $@

# report on all that do not have a direct equivalent in IPR
unmatched-domain.txt: domo.obo
	blip-findall -r go -i $< "class(ID),atom_concat('IPRGO:',Frag,ID),atom_concat('GO:',Frag,GID),subclassT(GID,'GO:0019904'),findall(Y,parent(ID,Y),Ys)" -select ID-Ys -label -no_pred | sort -u > $@
unmatched.txt: domo.obo
	blip-findall -r go -i $< "class(ID),atom_concat('IPRGO:',Frag,ID),findall(Y,parent(ID,Y),Ys)" -select ID-Ys -label -no_pred | sort -u > $@

matched.txt: domo.obo
	blip-findall -i $< "class(ID),id_idspace(ID,'IPR'),findall(Y,parent(ID,Y),Ys)" -select ID-Ys -label -no_pred > $@

# implicit GO-derived family/domain ontology classes with no IPR children;
# for those that are not already leaf proteins (todo - PR integration) we should find the IPR classes
no-ipr-children.txt: domo.obo
	blip-findall -i $< "class(C),id_idspace(C,'IPRGO'),\+subclass(_,C)" -select C -label | sort -u > $@

## ----------------------------------------
## Logical definitions of GO classes
## ----------------------------------------

# we use obol to parse GO labels of the form 'X binding'

clean:
	rm iprgo*

#new-domain.txt:
#	 obol qobol-newterms -ontology GO -tag domain  -subclass GO:0019904 > $@

x-domain-1.obo: domo.obo
	obol qobol -ontology GO -i $< -tag domain -subclass $(PB) -export obo > $@.tmp && cat $@.tmp  | obo-grep.pl -r IPR - > $@
#	obol qobol -ontology GO -i iprgo.obo -tag domain -subclass GO:0019904 -export obo > $@
x-domain.obo: x-domain-1.obo has_input.obo
	cat $^ > $@
x-domain.owl: x-domain.obo
	owltools $< -o $@

# this should now be in the ontology
x-protein.obo: $(GO_XP_PRO)
	obol qobol -ontology GO -xont PR -i $< -newonly -tag protein -tag binding -subclass $(PB) -export obo > $@.tmp && mv $@.tmp  $@

go-defined-classes.obo: ../../ontology/editors/gene_ontology_write.obo
	obo-grep.pl -r intersection_of: $< > $@

go-binding-subset-anc.obo:
	blip ontol-query -r go -query "subclassRT(ID,'$(PB)')" -to obo > $@

XIN = go-binding-subset-anc.obo x-domain.obo domo.obo
merged.owl: $(XIN)
	owltools $(XIN) --merge-support-ontologies -o $@
merged.obo: merged.owl
	owltools $< -o -f obo --no-check $@

merged-inf.obo: merged.owl
	owltools $< --assert-inferred-subclass-axioms --markIsInferred -o -f obo --no-check $@

## Protein to InterPro
protein2ipr-%.csv:
	fetch-protein2ipr.sh $* $@
.PRECIOUS: protein2ipr-%.csv

protein2ipr-%.ttl: protein2ipr-%.csv
	./csv2ttl.pl $< > $@.tmp && mv $@.tmp $@
.PRECIOUS: protein2ipr-%.ttl

protein2ipr-%.owl: protein2ipr-%.ttl
	owltools $< -o $@
protein2ipr-%.obo: protein2ipr-%.ttl
	owltools $< -o -f obo $@

merged-%.owl: protein2ipr-%.owl $(XIN)
	owltools $^ --merge-support-ontologies -o $@
merged-%.obo: merged-%.owl
	owltools $< --set-ontology-id $@ -o -f obo --no-check $@

