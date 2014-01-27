package App::ConfigMaker;

use utf8;
use strict;
use warnings;

# ABSTRACT: A tiny helper for configuration files on different environments
# VERSION

use Getopt::Std;
use Getopt::Config::FromPod;
use Pod::Usage;
use YAML::Any;
use Text::Template;
use File::Temp;
use File::Copy;

my $yaml = YAML::Any->implementation;
my $encoder = $yaml eq 'YAML::Syck' || $yaml eq 'YAML::Old' ? sub { shift; } : sub { Encode::encode('utf-8', shift); };

my %dispatch = (
	make => \&_make,
	install => \&_install,
	init => \&_init,
	check => \&_check,
);

my %opts;
my $conf;
my $CONF_PATH = "$ENV{HOME}/.config.yaml";

# hook for test
sub __set_conf
{
	$CONF_PATH = shift;
}

sub _resolve_one
{
	my $key = shift;
	my $flag;
	while($conf->{$key} =~ /{([^}]*)}/g) {
		$flag = 1;
		_resolve_one($1);
	}
	if($flag) {
		$conf->{$key} =~ s/{([^}]*)}/$conf->{$1}/ge;
	}
}

sub _resolve_conf
{
	foreach my $key (keys %$conf) {
		_resolve_one($key);
	}
}

# TODO: add tests
sub _expand
{
	my $value = shift;
	$value =~ s/{([^}]*)}/$conf->{$1}/ge;
	return $value;
}

# TODO: encoding/bom handling
# TODO: errors in code fragments MUST be notified
# TODO: it may be better to notify new variables also in YAML comment
sub _make
{
	my $control_path = $conf->{template_path}.'/control.yaml';
	if(! -f $control_path) {
		die "$control_path not found";
	}
	my $control = YAML::Any::LoadFile($control_path) or die "Can't load $control_path";
	foreach my $key (keys %{$control->{files}}) {
		open my $fh, '>', "$conf->{template_path}/${key}.out";
		print $fh Text::Template::fill_in_file("$conf->{template_path}/${key}.tmpl", DELIMITERS => ['{%', '%}'], HASH => $conf);
		close $fh;
	}
}

sub _install
{
	my $control_path = $conf->{template_path}.'/control.yaml';
	if(! -f $control_path) {
		die "$control_path not found";
	}
	my $control = YAML::Any::LoadFile($control_path) or die "Can't load $control_path";
	$ENV{EDITOR} = 'vi';
	foreach my $key (keys %{$control->{files}}) {
		my $fh = File::Temp->new;
		my $target = _expand($control->{files}{$key}{install});
		my $temp = $fh->filename;
		print "$target v.s. output\n";
		my $ret = system "sdiff -d -o '$temp' '$target' '$conf->{template_path}/${key}.out'";
		if($ret == 0) {
			print +('-'x72)."\nIdentical, skip\n".('-'x72)."\n";
		} elsif($ret == (1 << 8)) {
			print +('-'x72)."\nActual diff\n".('-'x72)."\n";
			system "diff -u '$target' '$temp'";
			print 'y/n> ';
			my $yn = <STDIN>;
			if($yn =~ /^\s*y\s*$/i) {
				print "Installing $target\n";
				rename $target => "${target}.bak" or warn "Backup failed, skip";
				copy $temp => $target;
			}
		} else {
			print +('-'x72)."\nError occurs, skip\n".('-'x72)."\n";
		}
	}
}

sub _init
{
	$conf = {};
	if(-f "$ENV{HOME}/.config.yaml") {
		if(! exists $opts{u}) {
			die "$CONF_PATH has already existed, specify -u if you actually want to update it";
		}
		$conf = YAML::Any::LoadFile($CONF_PATH);
	}
	$conf->{template_path} ||= "$ENV{HOME}/.conf";
	my $control_path = $conf->{template_path}.'/control.yaml';
	if(! -f $control_path) {
		die "$control_path not found";
	}
	my $control = YAML::Any::LoadFile($control_path) or die "Can't load $control_path";
	foreach my $key (keys %{$control->{variables}}) {
		next if exists $conf->{$key};
		if(exists $opts{u}) {
			print "Add new variable: $key\n";
		}
		$conf->{$key} = $control->{variables}{$key}{example};
	}
	YAML::Any::DumpFile($CONF_PATH, $conf);
}

sub _check
{
}

sub run
{
	shift if @_ && eval { $_[0]->isa(__PACKAGE__) };

	local (@ARGV) = @_;

	getopts(Getopt::Config::FromPod->string, \%opts);
	pod2usage(-verbose => 2) if exists $opts{h};
	pod2usage(-msg => 'At least one argument MUST be specified', -verbose => 0, -exitval => 1) if ! @ARGV;

	my $command = shift @ARGV;
	pod2usage(-msg => "Unkown command: $command", -verbose => 1, -exitval => 1) unless exists $dispatch{$command};
	if($command ne 'init') {
		$conf = YAML::Any::LoadFile($CONF_PATH) or die "$CONF_PATH not found}";
		_resolve_conf();
	}
	$dispatch{$command}->(@ARGV);
}

1;
__END__

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut
