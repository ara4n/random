#!/usr/bin/env perl

use 5.010;

use strict;
use warnings;

use XML::LibXML;
use YAML::PP;

my $dom = XML::LibXML->load_xml(location => 'entities.xml');
my $y = YAML::PP->new();

#say ($dom->to_literal());

my $issues = {};

foreach my $issue ($dom->findnodes('/entity-engine-xml/Issue')) {
    my $i;
    foreach my $attr ($issue->attributes) {
        $i->{ $attr->nodeName } = $attr->nodeValue;
    }
    my $desc = $issue->to_literal();
    $desc =~ s/^\s+//;
    $desc =~ s/\s+$//;
    $i->{description} = $desc;
    $issues->{$i->{id}} = $i;
}

foreach my $action ($dom->findnodes('/entity-engine-xml/Action')) {
    my $a;
    foreach my $attr ($action->attributes) {
        $a->{ $attr->nodeName } = $attr->nodeValue;
    }
    my $body = $a->{body} || $action->to_literal();
    $body =~ s/^\s+//;
    $body =~ s/\s+$//;
    $a->{body} = $body;
    push @{$issues->{ $a->{issue} }->{actions}}, $a;
}

foreach my $id (keys %$issues) {
    open (FILE, ">", "browse/".$issues->{$id}->{key}) || die $!;
    binmode FILE, ":utf8";
    my $actions = delete $issues->{$id}->{actions};
    for my $key (qw(summary)) {
        print FILE $y->dump_string({ $key => $issues->{$id}->{$key} });
        delete $issues->{$id}->{$key};
    }
    print FILE $y->dump_string($issues->{$id});
    print FILE $y->dump_string({ actions => $actions });
    close (FILE);
}
