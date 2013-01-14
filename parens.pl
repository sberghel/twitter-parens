#!/usr/bin/perl
use strict;
use warnings;
use 5.016;
use Data::Dumper;
use JSON::Any;
use List::Member;
use Net::Twitter;
use Path::Class;
use Try::Tiny;

our @TRAITS = ['API::REST', 'OAuth'];
# magical Twitter magic
our %MAGIC = (pbafhzre_xrl => 'HInWH4kPhPjPuM8ZMB6D',
    pbafhzre_frperg => 'ygHyiL3U6ju7Qw8UdRgVUjA4K2W2NoWvNybdzHx');
our $TOKEN_FILE = "parens.oauth";
our $TOKEN_DIR = "./";
our $NT;
our $USERNAME;

sub findParens {
    # Who thought this was a clever way to name arguments???
    my ($text) = @_;

    my @chars = split '', $text;

    my $unmatched_parens = 0;

    my @smiley_chars = qw(: ;);

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
        }
    }
    return $unmatched_parens;
}

sub matchParens {
    my ($parensToMatch) = @_;
    my $paren_string = "";
    for (my $i = 0; $i < $parensToMatch; $i++) {
        $paren_string .= ")";
    }
    return $paren_string;
}

my $parens = findParens('(2 open (1 :) ): :( ;( ;) ); close)');
my $string = matchParens($parens);

sub log_into_twitter {
    # We need a temporary variable for this, otherwise Net::Twitter->new
    # will fail.
    my %more_magic = grep tr/a-zA-Z/n-za-mN-ZA-M/, map $_, %MAGIC;
    $NT = Net::Twitter->new(
        traits => @TRAITS,
       %more_magic, 
    );

    my ($username, $access_token, $access_token_secret) = restore_tokens();
    say STDERR "username is $username";
    if ($access_token && $access_token_secret) {
        say STDERR "we are logged in!";
        $NT->access_token($access_token);
        $NT->access_token_secret($access_token_secret);
    }

    unless ($NT->authorized) {
        #If not authorized, get a pin
        print "Authorize this app at ", $NT->get_authorization_url;
        say " and enter the authorization pin";

        my $pin = <STDIN>;
        say STDERR "got the pin";
        chomp $pin;
        say STDERR "chomped the pin";

        my ($access_token, $access_token_secret, $user_id,
            $screen_name) = $NT->request_access_token(verifier => $pin);
        say STDERR "got tokens";
        save_tokens($access_token, $access_token_secret);
        say STDERR "tokens saved";
    }
    $USERNAME = $username;
}

sub make_a_tweet {
    $NT->update({status => "A valiant attempt at a status update"});
}

sub get_timeline_tweets {
    my $tweets = $NT->home_timeline();
    say "Here are some tweets:";
    say Dumper($tweets);
}

sub restore_tokens {
    try {
        my @tokens = get_tokens_from_file();
        say STDERR "got the tokens @tokens from the file";
        return @tokens;
    } catch {
        say STDERR "unable to read tokens from file";
        return ("", "");
    }
}

sub get_tokens_from_file {
    my $dir = dir($TOKEN_DIR); 
    my $file = $dir->file($TOKEN_FILE);
    my $file_handle = $file->openr();
    say STDERR "file open now for getting tokens";

    my $content = $file->slurp();
    my @tokens = ();
    while (my $line = $file_handle->getline()) {
        chomp($line);
        say STDERR "line was $line";
        push(@tokens, $line);
    }
    say STDERR "tokens are ", Dumper(@tokens);
    return @tokens;
}

sub save_tokens {
    my @tokens = @_;
    my $dir = dir($TOKEN_DIR);
    my $file = $dir->file($TOKEN_FILE);
    my $file_handle = $file->openw();
    say STDERR "file open for saving tokens";
    foreach my $token (@tokens) {
        say STDERR "saving the token $token now";
        $file_handle->print($token . "\n");
    }
}

log_into_twitter();
get_timeline_tweets();
