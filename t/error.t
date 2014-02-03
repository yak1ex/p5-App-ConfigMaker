use Test::More;
use Getopt::Config::FromPod;
Getopt::Config::FromPod->set_class_default(-file => 'bin/configmaker');

use App::ConfigMaker;

# command line arguments, regexp for STDOUT, exit status, test name
my @tests = (
	[[], qr/At least one argument MUST be specified/, 256, 'no argument'],
	[['nonexistent'], qr/Unkown command: nonexistent/, 256, 'unknowon command'],
);

plan tests => 2 * @tests;
check(@$_) for @tests;

sub check
{
	pipe(my $FROM_PARENT, my $TO_CHILD);
	pipe(my $FROM_CHILD, my $TO_PARENT);
	my $pid = fork;
	die "fork failed: $!" if ! defined($pid);
	if($pid) {
		close $FROM_PARENT;
		close $TO_PARENT;
		print $TO_CHILD $_[1];
		close $TO_CHILD;
		local $/ = undef;
		my $output = <$FROM_CHILD>;
		close $FROM_CHILD;
		like($output, $_[1], $_[3].' - out');
		waitpid $pid, 0;
		is($?, $_[2], $_[3].' - status');
	} else {
		close $FROM_CHILD;
		close $TO_CHILD;
		# Need to close first, at least, on Win32
		close STDIN;
		close STDOUT;
		open STDIN, '<&='.fileno($FROM_PARENT);
		open STDOUT, '>&='.fileno($TO_PARENT);
		close $FROM_PARENT;
		close $TO_PARENT;
		App::ConfigMaker->run(@{$_[0]});
		exit;
	}
}
