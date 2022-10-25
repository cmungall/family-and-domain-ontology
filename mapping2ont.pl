#!/usr/bin/perl -w
use strict;
while (<>) {
    next if /^ENTRY/;
    chomp;
    s/IPR(\d+)/IPR:$1/g;
    s/\"//g;
    my ($ipr,$t,$n,$goid,$gon) = split(/\t/,$_);
    my $pid = $goid;
    $pid =~ s/GO:/IPRGO:/;
    my $pn = $gon;
    $pn =~ s/ binding//;

    print "[Term]\n";
    print "id: $pid\n";
    print "name: $pn\n";
    print "is_a: IPR:000000\n";
    print "\n";

    print "[Term]\n";
    print "id: $ipr\n";
    print "name: $n\n";
    print "is_a: $pid ! $pn\n";
    #print "is_a: IPR:000000\n";
    #print "relationship: part_of $pid ! $pn\n";
    print "\n";

}

print "\n[Typedef]\n";
print "id: part_of\n";
print "name: part_of\n";
print "xref: BFO:0000050\n";

