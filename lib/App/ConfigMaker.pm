package App::ConfigMaker;

use strict;
use warnings;

# ABSTRACT: A tiny helper for configuration files on different environments
# VERSION

use Getopt::Std;
use Getopt::Config::FromPod;
use Pod::Usage;
use YAML::Any;

my $yaml = YAML::Any->implementation;
my $encoder = $yaml eq 'YAML::Syck' || $yaml eq 'YAML::Old' ? sub { shift; } : sub { Encode::encode('utf-8', shift); };

sub run
{
	shift if @_ && eval { $_[0]->isa(__PACKAGE__) };

	local (@ARGV) = @_;

	my %opts;
	getopts(Getopt::Config::FromPod->string, \%opts);
	pod2usage(-verbose => 2) if exists $opts{h};
	pod2usage(-msg => 'At least one argument MUST be specified', -verbose => 0, -exitval => 1) if ! @ARGV;
}

1;
__END__

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut
