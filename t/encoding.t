use Test::More;
use Test::Exception;

use FindBin;
use File::Temp;
use File::Copy::Recursive qw(dircopy);
use Getopt::Config::FromPod;
Getopt::Config::FromPod->set_class_default(-file => 'bin/configmaker');

BEGIN {
our @key = qw(utf8 utf8bom utf16le utf16lebom utf16be utf16bebom sjiscrlf euclf);
plan tests => 2 + 2 * @key;
use_ok('App::ConfigMaker');
}

sub content
{
	my $fh;
	my $file = shift;
	if(ref $file) {
		$fh = $file;
	} else {
		open $fh, '<', $file;
	}
	local $/;
	my $content = <$fh>;
	close $fh unless ref $file;
	return $content;
}

my $dir1 = File::Temp->newdir();
my $dir2 = File::Temp->newdir(CLEANUP => 0);
dircopy("$FindBin::Bin/encoding", "$dir1/encoding");
App::ConfigMaker::__set_conf("$dir1/conf.yaml");
{
	open my $fh, '>', "$dir1/conf.yaml";
	print $fh <<EOF;
template_dir: $dir1/encoding
var: 'example value'
test_dist: $dir2
EOF
	close $fh;
}
lives_ok { App::ConfigMaker->run('make'); } 'invoke make command';
for my $type (@key) {
	ok(-f "$dir1/encoding/test.$type.ini.out", "exists output for $type");
	is(content("$dir1/encoding/test.$type.ini.out"), content("$FindBin::Bin/encoding_result/test.$type.ini.out"), "output for $type by make command");
}
