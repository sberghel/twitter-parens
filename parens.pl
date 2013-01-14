#!/usr/bin/perl
use strict;
use warnings;
use 5.016;
use List::Member;

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
            my $nextchar = $chars[$index+1];
            my $prevchar = $chars[$index-1];
            if ($index == 0) {
                # Don't look at the previous character, since we're at
                # the beginning of the string
                
                # "Unless" is how perl says "if ![condition]."
                # member returns -1 if a thing is not a member and 0
                # if it is.
                unless ( member($nextchar, @smiley_chars) + 1) {
                    $unmatched_parens++;
                }
            } elsif ($index == $#chars) {
                # Don't look at the next character, since we're at the
                # end of the string
                unless ( member($prevchar, @smiley_chars) + 1) {
                    $unmatched_parens++;
                }
            } else {
                unless ( (member($prevchar, @smiley_chars) + 1) ||
                    (member($nextchar, @smiley_chars) + 1)) {
                    $unmatched_parens++;
                }
            }
            say "Look, I found an open paren.";
        } elsif ($elem eq ")") {
            my $nextchar = $chars[$index+1];
            my $prevchar = $chars[$index-1];
            if ($index == 0) {
                unless ( member($nextchar, @smiley_chars) + 1) {
                    $unmatched_parens--;
                }
            } elsif ($index == $#chars) {
                unless ( member($prevchar, @smiley_chars) + 1) {
                    $unmatched_parens--;
                }
            } else {
                unless ( (member($prevchar, @smiley_chars) + 1) ||
                    (member($nextchar, @smiley_chars) +1)) {
                    $unmatched_parens--;
                }
            }
            say "Look, I found a closing paren";
        }
    }
    say "I found $unmatched_parens unmatched parens";
}

matchParens('(2 open (1 :) ): close)')
