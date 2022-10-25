#!/usr/bin/perl

print "\@prefix        : <http://purl.obolibrary.org/obo/> .\n";
print "\@prefix       u: <http://purl.obolibrary.org/obo/UniProtKB_> .\n";
####print "\@prefix       i: <http://purl.obolibrary.org/obo/InterPro_> .\n";
print "\@prefix       i: <http://purl.obolibrary.org/obo/IPR_> .\n";
print "\@prefix    rdfs: <http://www.w3.org/2000/01/rdf-schema#> .\n";
print "\n";

my @lines = sort {$a cmp $b} (<>);
foreach (@lines) {
    chomp;
    next unless m/^http/;
    if (m@^http://purl.uniprot.org/uniprot/(\w+),http://purl.uniprot.org/interpro/IPR(\d+)@) {
        print "u:$1 rdfs:subClassOf i:$2 .\n";
    }
    else {
        die "Cannot parse: '$_'";
    }

}
