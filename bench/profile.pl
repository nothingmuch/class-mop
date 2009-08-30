#!perl -w
# Usage: perl bench/profile.pl (no other options including -Mblib are reqired)
use strict;

my $branch = do{
	open my $in, '.git/HEAD' or die "Cannot open .git/HEAD: $!";
	my $s = scalar <$in>;
	chomp $s;
	$s =~ s{^ref: \s+ refs/heads/}{}xms;
	$s =~ s{/}{_}xmsg;
	$s;
};

my $extra = shift || 'KiokuDB';

print "Profiling $branch (require $extra) ...\n";

my @cmd = ($^X, '-Iblib/lib', '-Iblib/arch', '-e', "require Moose; require $extra");
print "> @cmd\n";
system(@cmd) == 0 or die "Cannot profile";
system(@cmd) == 0 or die "Cannot profile";
system(@cmd) == 0 or die "Cannot profile";

@cmd = ($^X, '-S', 'nytprofhtml', '--out', "nytprof-$branch");
print "> @cmd\n";
system(@cmd) == 0 or die "Cannot profile";
