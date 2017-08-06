#!/usr/bin/perl -w
#
# An implementation of "Automatic Removal of 'Garbage Strings' in OCR Text" by
# TAGHVA et al. at the ISRI.
#
# Only UTF-8 is supported.
#
# Reads text or file from STDIN.
# Writes the same text minus words deemed garbage to standard output.
#
use strict;
use warnings;
use English;

binmode(STDIN,  ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

while (<>) {
    chomp();
    next unless m/\S/;
    foreach my $word (split(/\s+/)) {
        if (isgarbage($word)) {
            print STDERR "\t[discarded because " . isgarbage($word) . ": L=" . length($word) . " $word]\n";
        } else {
            print "$word ";
        }
    }
    print "\n";
}


sub isgarbage {
    my $string = shift();
    # FIXME: state and/or check there's no whitespace!

    # Rule 'L': "If a string is longer than 40 characters, it is garbage"
    if (length($string) > 40) {
        return 'L';
    }

    # Rule 'A': "If a string's ratio of alphanumeric characters to total
    # characters is less than 50%, the string is garbage"
    #
    # FIXME: fails 1.1). --- perhaps an applicability threshold on length?
    # Or perhaps there should be a sliding scale with length, e.g. a 5-char
    # string is allowed 40% alnum, etc.?
    my $alnum_ratio_thresholds = {
      1 => 0,    # single chars can be non-alphanumeric
      2 => 0,    # so can doublets
      3 => 0.32, # at least one of three should be alnum
      4 => 0.24, # at least one of four should be alnum
      5 => 0.39, # at least two of five should be alnum
      # anything other length string should use the default of at least half
    };
    #
    # Idiom: $str =~ tr/x// yields the count of 'x' in $str, without changing
    # $str.
    my $num_alphanumerics = scalar($string =~ tr/a-zA-Z0-9//);
    my $thresh = 0.49;
    if (exists($alnum_ratio_thresholds->{length($string)})) {
        $thresh = $alnum_ratio_thresholds->{length($string)};
    }
    #if ($string =~ m/uphill/) {
    #    print STDERR "'A' for $string: alpha: $num_alphanumerics; total: " . length($string) . "; ratio: " . $num_alphanumerics / length($string) . "\n";
    #}
    if ($num_alphanumerics / length($string) < $thresh) {
        return 'A';
    }

    # Rule 'R': "If a string has 4 identical characters in a row, it is
    # garbage"
    # FIXME: fails 0.00005
    if ($string =~ m/(.)\1{3,}/) {
        return 'R';
    }

    # Rule 'V': "If a string has nothing but alphabetic characters, look at the
    # number of consonants and vowels. If the number of one is less than 10% of
    # the number of the other, then the string is garbage."
    #
    # This is buggy unless length-thresholded (e.g. 'a' and 'I' are all vowel).
    if ($string =~ m/^[a-z]+$/i) {
        # Same idiom as Rule 'A'.
        my $num_vowels = scalar($string =~ tr/aeiouAEIOU//);
        my $num_consonants = length($string) - $num_vowels;

        if ($num_consonants > 0 and $num_vowels > 0) {
            my $ratio = $num_vowels / $num_consonants;

            if ($num_vowels > 0 and ($ratio < .10 or $ratio > 10)) {
                return 'V';
            }
        } elsif ($num_vowels == 0 and $num_consonants > length("rhythms")) {
            return 'V';
        } elsif ($num_consonants == 0 and $num_vowels > length("eau")) {
            return 'V';
        }
    }

    # Rule 'P': "Strip off the first and last characters of a string. If there
    # are two distinct punctuation characters in the result, then the string is
    # garbage"
    if ($string =~ m/^.([[:punct:]]).$/) {
        my $punct = $1;
        my $string_middle = $string;
        $string_middle =~ s/^.(.*).$/$1/;
        while ($string_middle =~ m/([[:punct:]])/g) {
            if ($1 ne $punct) {
                return 'P';
            }
        }
    }

    # Rule 'C': "If a string begins and ends with a lowercase letter, then if
    # the string contains an uppercase letter anywhere in between, then it is
    # removed as garbage."
    #
    # Customisation: false positive on "needed.The".  Exclude fullstop-capital.
    if ($string =~ m/^[a-z].*[A-Z].*[a-z]$/ and $string !~ m/\.[A-Z]/) {
        return 'C';
    }

    return undef;
}
