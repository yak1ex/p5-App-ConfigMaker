use Test::More tests => 12;
use Test::Exception;

use FindBin;
use File::Temp;
use File::Copy::Recursive qw(dircopy);
use Getopt::Config::FromPod;
Getopt::Config::FromPod->set_class_default(-file => 'bin/configmaker');

BEGIN {
use_ok('App::ConfigMaker');
}

sub content
{
	my $file = shift;
	local $/;
	open my $fh, '<', $file;
	my $content = <$fh>;
	close $fh;
	return $content;
}

my $dir1 = File::Temp->newdir();
my $dir2 = File::Temp->newdir();
dircopy("$FindBin::Bin/tmpl", "$dir1/tmpl");
App::ConfigMaker::__set_conf("$dir1/conf.yaml");
lives_ok { App::ConfigMaker->run('init', "$dir1/tmpl"); } 'invoke init command';
like(content("$dir1/conf.yaml"), qr[---\ntemplate_dir: .*/tmpl\nvar: '{ EXAMPLE }example value'\n], 'config.yaml content by init command');
open my $fh, '>', "$dir1/conf.yaml";
print $fh <<EOF;
template_dir: $dir1/tmpl
var: 'example value'
test_dist: $dir2
EOF
close $fh;

lives_ok { App::ConfigMaker->run('make'); } 'invoke make command';
ok(-f "$dir1/tmpl/test.ini.out", 'exists output');
is(content("$dir1/tmpl/test.ini.out"), <<EOF, 'output by make command');
[test]
example value=example value
EOF

# TODO: Suppress or check stdout
# install when not yet existed
lives_ok { App::ConfigMaker->run('install'); } 'invoke install command';
ok(-f "$dir2/test.ini", 'exists output');
is(content("$dir2/test.ini"), <<EOF, 'output by install command');
[test]
example value=example value
EOF

# install when identical
lives_ok { App::ConfigMaker->run('install'); } 'invoke install command again';
ok(-f "$dir2/test.ini", 'exists output');
is(content("$dir2/test.ini"), <<EOF, 'output by install command');
[test]
example value=example value
EOF

# TODO: install by sdiff
# TODO: check