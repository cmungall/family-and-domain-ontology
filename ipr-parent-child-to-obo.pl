#!/usr/bin/perl -w
use strict;

my $url = 'ftp://ftp.ebi.ac.uk/pub/databases/interpro/ParentChildTreeFile.txt';
my $root = "IPR:000000";
my %nh = ();
$nh{$root} = 'domain';

my @stack = ($root);
while (<>) {
    chomp;
    s/IPR(\d+)/IPR:$1/;
    if (m@^(\-*)(IPR:\d+)::(.*)::@) {
        my ($len, $id, $name) = ($1,$2,$3);
        $nh{$id} = $name;
        $len = length($len)/2 + 1;
        #if ($len > 1) {die};
        while ($len < scalar(@stack)) {
            pop @stack;
        }
        my $parent = $stack[-1];
        print "[Term]\n";
        print "id: $id\n";
        print "name: $name\n";
        print "is_a: $parent ! $nh{$parent}\n";
        #print "depth: $len\n";
        print "\n";
        push(@stack, $id);
    }
    else {
        die $_;
    }
}
