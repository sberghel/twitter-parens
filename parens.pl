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

our @TRAITS = ['API::REST', 'OAuth', 'AutoCursor'];
# magical Twitter magic
our %MAGIC = (pbafhzre_xrl => 'HInWH4kPhPjPuM8ZMB6D',
    pbafhzre_frperg => 'ygHyiL3U6ju7Qw8UdRgVUjA4K2W2NoWvNybdzHx');
our $TOKEN_FILE = "parens.oauth";
our $TOKEN_DIR = "./";
our $TWEETS_FILE = "last.tweet";
our $NT;
our $USERNAME;
# Debug variable. If it evaluates to True, you'll get debug messages on
# STDERR.
# If it evaluates to False, you won't.
our $DEBUG = 0;

sub find_parens {
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
        } elsif ( ($elem eq ")") && ($unmatched_parens > 0) ) {
            my $nextchar = $chars[$index+1];
            my $prevchar = $chars[$index-1];
            if ($index == 0) {
                unless ( member($nextchar, @smiley_chars) + 1) {
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

sub match_parens {
    my ($parens_to_match) = @_;
    my $paren_string = "";
    for (my $i = 0; $i < $parens_to_match; $i++) {
        $paren_string .= ")";
    }
    return $paren_string;
}

sub log_into_twitter {
    # We need a temporary variable for this, otherwise Net::Twitter->new
    # will fail.
    my %more_magic = grep tr/a-zA-Z/n-za-mN-ZA-M/, map $_, %MAGIC;
    $NT = Net::Twitter->new(
        traits => @TRAITS,
       %more_magic, 
    );

    my ($username, $access_token, $access_token_secret) = restore_tokens();
    $USERNAME = $username;
    if ($access_token && $access_token_secret) {
        $NT->access_token($access_token);
        $NT->access_token_secret($access_token_secret);
    }

    unless ($NT->authorized) {
        #If not authorized, get a pin
        print "Authorize this app at ", $NT->get_authorization_url;
        say " and enter the authorization pin";

        my $pin = <STDIN>;
        chomp $pin;

        my ($access_token, $access_token_secret, $user_id,
            $screen_name) = $NT->request_access_token(verifier => $pin);
        $USERNAME = $screen_name;
        save_tokens($access_token, $access_token_secret);
    }

    if ($DEBUG) {
        say STDERR "Logged in as ", $USERNAME;
    }
}

sub get_timeline_tweets {
    my $tweets = $NT->home_timeline( {"count" => 100,
        since_id => get_last_replied_tweet() - 1} );
    if ($DEBUG) {
        say STDERR "Here are some tweets:";
        foreach my $tweet (@{ $tweets }) {
            say STDERR $tweet->{text};
        }
    }
    return @{ $tweets };

}

sub find_parens_in_tweets {
    my @tweets = @_;
    my $last_tweet = get_last_replied_tweet();
    if ($DEBUG) {
        say STDERR "We last replied to ", $last_tweet;
    }
    foreach my $tweet (@tweets) {
        my $num_parens = find_parens($tweet->{text});
        if ($DEBUG) {
            #say "We found $num_parens unmatched parens";
        }
        if ($num_parens > 0) {
            if ($tweet->{id} > $last_tweet) {
                my $new_tweet = match_parens($num_parens);
                $new_tweet = "@" . $tweet->{user}->{screen_name} . 
                    " " . $new_tweet;
                if ($DEBUG) {
                    say STDERR "We are going to tweet: $new_tweet";
                    say STDERR "And we will tweet it in reply to ", 
                        $tweet->{id},
                        " by the user ", $tweet->{user}->{screen_name};
                }

                # We have to save in this function.
                # Otherwise if replying crashes, we never save.
                # (Sometimes "update" throws an error when it succeeds.)
                save_last_replied_tweet($tweet->{id});

                # Reply to that tweet
                $NT->update({status => $new_tweet,
                        in_reply_to_status_id => $tweet->{id} });
                if ($DEBUG) {
                    say STDERR "replied";
                }
            } else {
                if ($DEBUG) {
                    say STDERR "we already responded to ", $tweet->{id};
                }
            }
        }
    }
}

sub save_last_replied_tweet {
    my ($tweet_id) = @_;
    my $file = dir($TOKEN_DIR)->file($TWEETS_FILE);
    $file->spew($tweet_id);
}

sub get_last_replied_tweet {
    try {
        my $tweet = get_tweet_from_file();
        if ($DEBUG) {
            say STDERR "got tweet from file";
        }
        return $tweet;
    } catch {
        say STDERR "failed to get tweet from file; defaulting to 0";
        return 0;
    }
}

sub get_tweet_from_file {
    my $file = dir($TOKEN_DIR)->file($TWEETS_FILE);
    my @lines = $file->slurp();
    if ($#lines == -1) {
        #if the file is empty, assume we've never responded
        return 0;
    } elsif ($#lines == 0) {
        #if we have just one line, return that one
        return $lines[0];
    } else {
        die "We can't have more than one last tweet";
    }
}

sub restore_tokens {
    try {
        my @tokens = get_tokens_from_file();
        return @tokens;
    } catch {
        say STDERR "Unable to read tokens from file.";
        return ("", "");
    }
}

sub get_tokens_from_file {
    my $file = dir($TOKEN_DIR)->file($TOKEN_FILE); 
    my $file_handle = $file->openr();

    my $content = $file->slurp();
    my @tokens = ();
    while (my $line = $file_handle->getline()) {
        chomp($line);
        push(@tokens, $line);
    }
    return @tokens;
}

sub save_tokens {
    my @tokens = @_;
    my $dir = dir($TOKEN_DIR);
    my $file = $dir->file($TOKEN_FILE);
    my $file_handle = $file->openw();
    foreach my $token (@tokens) {
        $file_handle->print($token . "\n");
    }
}

sub get_followers {
    my $followers_ref = $NT->followers_ids( {"screen_name" => $USERNAME} );
    return ref_to_array($followers_ref);
}

sub ref_to_array {
    my ($ref) = @_;
    my @array;
    # The ref could be a ref either an array or a hash.
    # Make sure we set the array to a list of IDs.
    if (ref($ref) eq "HASH") {
        @array = $ref->{ids};
    } else {
        @array = @{ $ref };
    }
    return @array;
}

sub get_friends {
    my $friends_ref = $NT->friends_ids( {"screen_name" => $USERNAME} );
    return ref_to_array($friends_ref);
}

sub prune_friends {
    my @followers = get_followers();
    my @friends = get_friends();
    for my $friend (@friends) {
        unless ( member($friend, @followers) + 1){
            if ($DEBUG) {
                print STDERR "unfollowing user with id $friend";
                print STDERR " and screenname ";
                my $user = $NT->lookup_users({"user_id" => $friend});
                say STDERR @{$user}[0]->{screen_name};
            }
            $NT->destroy_friend({"user_id" => $friend});
        }
    }
}

sub add_friends {
    my @followers = get_followers();
    my @friends = get_friends();
    for my $follower (@followers) {
        unless ( member($follower, @friends) + 1) {
            if ($DEBUG) {
                print STDERR "following user with id $follower";
                print STDERR " and screenname ";
                my $user = $NT->lookup_users({"user_id" => $follower});
                say STDERR @{$user}[0]->{screen_name};
            }
            $NT->create_friend({"user_id" => $follower});
        }
    }
}

log_into_twitter();
prune_friends();
add_friends();
my @tweets = get_timeline_tweets();
find_parens_in_tweets(@tweets);
