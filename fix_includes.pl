#!/usr/bin/perl
use strict;
use warnings;
use File::Find;
use Cwd 'abs_path';
use File::Basename 'dirname';

# Check for input directory
my $target_dir = $ARGV[0];
if (!$target_dir) {
    die "Usage: $0 <directory_containing_headers>\n";
}

# Convert to absolute path
my $root_dir = abs_path($target_dir);
print "Processing headers in: $root_dir\n";

find(sub {
    return unless /\.h$/;
    process_file($File::Find::name);
}, $root_dir);

sub process_file {
    my $current_file = abs_path(shift);
    my $current_dir  = dirname($current_file);

    open(my $fh, '<', $current_file) or warn "Could not open $current_file: $!";
    my $original_content = do { local $/; <$fh> };
    close($fh);

    my $modified_content = $original_content;

    # Matches #include <path> OR #include "path"
    # Group 1: opening delimiter (< or ")
    # Group 2: the path itself
    # Group 3: closing delimiter (> or ")
    $modified_content =~ s/#include\s+([<"])([^>"]+)([>"])/
        rewrite_include($current_dir, $root_dir, $1, $2, $3)
    /ge;

    if ($original_content ne $modified_content) {
        open(my $out, '>', $current_file) or warn "Could not write to $current_file: $!";
        print $out $modified_content;
        close($out);
        print "Updated: $current_file\n";
    }
}

sub rewrite_include {
    my ($current_dir, $root_dir, $open_delim, $include_path, $close_delim) = @_;

    # 1. Safety check: If the path already starts with a dot, it's already relative.
    # We leave these alone to avoid corrupting existing relative paths.
    if ($include_path =~ /^\.\// || $include_path =~ /^\.\./) {
        return qq(#include $open_delim$include_path$close_delim);
    }

    # Fix for a broken '#include "ht.h"' which actually lives in `ext/ht.h`.
    if ($include_path eq "ht.h" && !(-e "$root_dir/$include_path")) {
        $include_path = "ext/ht.h"
    }

    # 2. Construct the absolute path based on the root directory
    my $target_abs_path = "$root_dir/$include_path";

    if (-e $target_abs_path) {
        # Internal file found: Calculate geometry-based relative path
        my $rel_path = calculate_relative_path($current_dir, $target_abs_path);
        return qq(#include "$rel_path");
    } else {
        # File not in root: Keep the original delimiters and path (system header)
        return qq(#include $open_delim$include_path$close_delim);
    }
}

sub calculate_relative_path {
    my ($from_dir, $to_file) = @_;
    $from_dir = abs_path($from_dir);
    $to_file = abs_path($to_file);

    my @from_parts = split('/', $from_dir);
    my @to_parts   = split('/', $to_file);

    while (@from_parts && @to_parts && $from_parts[0] eq $to_parts[0]) {
        shift @from_parts;
        shift @to_parts;
    }

    my $relative = "../" x scalar(@from_parts);
    $relative .= join('/', @to_parts);
    return $relative;
}

print "Done.\n";
