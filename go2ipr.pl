#!/usr/bin/perl

# takes a subset of GO in obo format;
# WE ASSUME THIS HAS BEEN PRE-FILTERED
# only X binding classes

while (<>) {

    # hack the ID;
    # both the id field and the is_a field is covered here
    s@GO:@IPRGO:@g;

    # hack the name
    s@ selective binding@@;
    s@ binding@@;

    # hack the namespace
    s@namespace:.*@namespace: iprgo@;

    # Take advantage of terms like:
    #   id: GO:0097162
    #   name: MADS box domain binding
    #   def: "Interacting selectively and non-covalently with a MADS box domain, a protein domain that encodes the DNA-binding MADS domain. The MADS domain binds to DNA sequences of high similarity to the motif CC[A/T]6GG termed the CArG-box. MADS-domain proteins are generally transcription factors. The length of the MADS-box is in the range of 168 to 180 base pairs." [GOC:yaf, InterPro:IPR002100, PMID:18296735, Wikipedia:MADS-box]

    # hack the definition
    # also ensure equivalence
    s@Interacting selectively and non-covalently with @@;
    if (m@^def:.*InterPro:IPR(\d+)@) {
        print "equivalent_to: IPR:$1\n";
    }

    # root class hacking
    s@IPRGO:0019904@IPR:000000@;

    # write;
    # note that everything is passed through; 
    print;

    $id = $1 if m@^id: (\S+)@;

    # use the original IPR label as a synonym
    if (m@^name: (.*)@) {
        print "synonym: \"$1\" EXACT [$id]\n";
    }
}
