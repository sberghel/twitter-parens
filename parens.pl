#!/usr/bin/perl
use strict;
use warnings;
use 5.016;

sub matchParens {
    # Who thought this was a clever way to name arguments???
    my ($text) = @_;
    say "Text is $text";

    my @chars = split '', $text;
    say "Chars are @chars";

    my $unmatched_parens = 0;

    my @smiley_chars = qw(: ;);
    say "smileys are @smiley_chars";

    while (my ($index, $elem) = each @chars) {
        if ($elem eq "(") {
            if ($index == 0) {
                my $nextchar = $chars[$index+1];
            }
            my $prevchar = $chars[$index-1];
            say "Look, I found an open paren.";
        } elsif ($elem eq ")") {
            say "Look, I found a closing paren at index $index";
        }
    }
}

matchParens('(2 open (1 close)')
