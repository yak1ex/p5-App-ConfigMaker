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
use File::Path;
use File::Basename;
use Encode;

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
		_resolve_one($1) unless $1 =~ /^[A-Z]/;
	}
	if($flag) {
		$conf->{$key} =~ s/{([^}]*)}/$conf->{$1} || $ENV{$1} || ''/ge;
	}
}

sub _resolve_conf
{
	foreach my $key (keys %$conf) {
		_resolve_one($key);
	}
}

sub _expand
{
	my $value = shift;
	$value =~ s/{([^}]*)}/$conf->{$1}/ge;
	return $value;
}

sub _get_control
{
	die "template_dir is not defined in $CONF_PATH" unless exists $conf->{template_dir};
	die "template_dir defined in $CONF_PATH is not a directory" unless -d $conf->{template_dir};
	my $control_path = $conf->{template_dir}.'/control.yaml';
	if(! -f $control_path) {
		die "$control_path not found";
	}
	return YAML::Any::LoadFile($control_path) or die "Can't load $control_path";
}

sub _make
{
	my $control = _get_control();
	my %arg = (%ENV, %$conf);
	my $error;
	my @arg = (
		DELIMITERS => ['{%', '%}'],
		HASH => \%arg,
		BROKEN => sub {
			my %arg = @_;
			$error = "Program fragment delivered error ``$arg{error} at template line $arg{lineno}''";
			return;
		},
	);
	$arg{include} = sub { Text::Template::fill_in_file($conf->{template_dir}.'/'.shift, @arg);  };
	foreach my $key (keys %{$control->{files}}) {
		undef $error;
		my $result = Text::Template::fill_in_file("$conf->{template_dir}/${key}.tmpl", @arg);
		if(defined $error) {
			print STDERR "$error\n";
			next;
		}

		my ($encoding, $bom, $linebreak) = @{$control->{files}{$key}}{qw(encoding bom linebreak)};
		if($encoding) {
			if(Encode::find_encoding($encoding)) {
				$result = Encode::encode($encoding, Encode::decode('utf-8', $result));
			} else { warn "Unknown encoding: $encoding"; }
		}
		if($bom) {
			if($encoding =~ /^utf.*8$/i) { $result = "\xef\xbb\xbf" . $result; }
			elsif($encoding =~ /^utf.*16be$/i) { $result = "\xfe\xff" . $result; }
			elsif($encoding =~ /^utf.*16(le)?$/i) { $result = "\xff\xfe" . $result; }
			else { warn "Unknwon encoding for BOM: $encoding"; }
		}
		if($linebreak) {
			if($linebreak =~ /^LF$/i) {
				$result =~ s/\r\n/\n/g;
				$result =~ s/\r/\n/g;
			} elsif($linebreak =~ /^CRLF$/i) {
				$result =~ s/\r\n/\n/g;
				$result =~ s/\r|\n/\r\n/g;
			} elsif($linebreak =~ /^CR$/i) {
				$result =~ s/\r\n/\r/g;
				$result =~ s/\n/\r/g;
			} else {
				warn "Unknown linebreak type: $linebreak";
			}
		}
		open my $fh, '>', "$conf->{template_dir}/${key}.out";
		print $fh $result;
		close $fh;
	}
}

sub _install
{
	my $control = _get_control();
	$ENV{EDITOR} = 'vi';
	foreach my $key (keys %{$control->{files}}) {
		my $target = _expand($control->{files}{$key}{install});
		if(-f $target) {
			my $fh = File::Temp->new;
			my $temp = $fh->filename;
			print "$target v.s. output\n";
			my $ret = system "sdiff -d -o '$temp' '$target' '$conf->{template_dir}/${key}.out'";
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
		} else {
			print +('-'x72)."\nDestination not yet existed, just copy\n".('-'x72)."\n";
			my $dir = dirname $target;
			File::Path::make_path($dir) unless -d $dir;
			copy "$conf->{template_dir}/${key}.out" => $target;
		}
	}
}

sub _init
{
	my $update;
	if(defined $_[0] && $_[0] eq '-u') {
		$update = 1;
		shift;
	}
	$conf = {};
	if(-f $CONF_PATH) {
		if(! defined $update) {
			die "$CONF_PATH has already existed, specify -u if you actually want to update it";
		}
		$conf = YAML::Any::LoadFile($CONF_PATH);
	}
	$conf->{template_dir} = File::Spec->rel2abs($_[0]) if defined $_[0];
	$conf->{template_dir} ||= "$ENV{HOME}/.conf";
	my $control = _get_control();
	foreach my $key (keys %{$control->{variables}}) {
		next if exists $conf->{$key};
		if(defined $update) {
			print "Add new variable: $key\n";
		}
		$conf->{$key} = '{ EXAMPLE }'.$control->{variables}{$key}{example};
	}
	YAML::Any::DumpFile($CONF_PATH, $conf);
}

sub _check
{
	my $control = _get_control();
	my %var;
	foreach my $key (keys %{$control->{files}}) {
		local $/;
		open my $fh, "<", "$conf->{template_dir}/${key}.tmpl";
		my $cont = <$fh>;
		close $fh;
		while($cont =~ /({%.*?%})/gs) {
			my $frag = $1;
			while($frag =~ /\$(?:(\w+)|{([^}]+)})\b/g) {
				$var{$1||$2} = 1;
			}
		}
	}
	foreach my $var (keys %var) {
		next if $var =~ /^(?:OUT|_.*)$/;
		if($var =~ /^[A-Z]/) {
			warn "Variable: $var in templates not defined in environment variables" unless exists $ENV{$var};
		} else {
			warn "Variable: $var in templates not in $conf->{template_dir}/control.yaml" unless exists $control->{variables}{$var};
			warn "Variable: $var in templates not in $CONF_PATH" unless exists $conf->{$var};
		}
	}
	foreach my $var (keys %{$control->{variables}}) {
		warn "Variable: $var in $conf->{template_dir}/control.yaml not in $CONF_PATH" unless exists $conf->{$var};
	}
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
		$conf = YAML::Any::LoadFile($CONF_PATH) or die "$CONF_PATH not found";
		_resolve_conf();
	}
	$dispatch{$command}->(@ARGV);
}

1;
__END__

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut
