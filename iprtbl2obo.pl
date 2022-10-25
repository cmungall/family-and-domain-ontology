#!/usr/bin/perl
while(<>){
    chomp;
    my ($id,$n,$sn,$type) = split(/\|/,$_);
    next unless $id =~ /IPR/;
    $id =~ s/IPR/IPR:/;
    print "[Term]\n";
    print "id: $id\n";
    print "synonym: \"$n\" EXACT [$id]\n";
    print "synonym: \"$sn\" EXACT [$id]\n";
    print "subset: $type\n";
    print "\n";
}
