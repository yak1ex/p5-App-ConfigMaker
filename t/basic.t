use Test::More tests => 21;
use Test::Exception;

use FindBin;
use File::Temp;
use File::Copy::Recursive qw(dircopy);
use Getopt::Config::FromPod;
Getopt::Config::FromPod->set_class_default(-file => 'bin/configmaker');

BEGIN {
use_ok('App::ConfigMaker');
}

# TODO: Move exceptional cases to another file

App::ConfigMaker::__set_conf("$FindBin::Bin/nonexistent.yaml");
throws_ok { App::ConfigMaker->run('make'); } qr/nonexistent\.yaml/, 'nonexistent config.yaml other than init';

App::ConfigMaker::__set_conf("$FindBin::Bin/error.yaml");
throws_ok { App::ConfigMaker->run('make'); } qr/template_dir is not defined/, 'config.yaml having no template_dir other than init';

App::ConfigMaker::__set_conf("$FindBin::Bin/nodir.yaml");
throws_ok { App::ConfigMaker->run('make'); } qr/template_dir defined in .* is not a directory/, 'config.yaml having not directory template_dir other than init';

App::ConfigMaker::__set_conf("$FindBin::Bin/nocontrol.yaml");
throws_ok { App::ConfigMaker->run('make'); } qr/control.yaml not found/, 'config.yaml having template_dir without control.yaml other than init';

App::ConfigMaker::__set_conf("$FindBin::Bin/invalid.yaml");
throws_ok { App::ConfigMaker->run('make'); } qr/YAML/, 'config.yaml having template_dir with invalid control.yaml other than init';

throws_ok { App::ConfigMaker->run('init'); } qr/has already existed, specify -u if you actually want to update it/, 'config.yaml already existed on init';

App::ConfigMaker::__set_conf("$FindBin::Bin/nodir.yaml");
throws_ok { App::ConfigMaker->run(qw(init -u)); } qr/template_dir defined in .* is not a directory/, 'config.yaml having not directory template_dir on init';

App::ConfigMaker::__set_conf("$FindBin::Bin/nocontrol.yaml");
throws_ok { App::ConfigMaker->run(qw(init -u)); } qr/control.yaml not found/, 'config.yaml having template_dir without control.yaml on init';

App::ConfigMaker::__set_conf("$FindBin::Bin/invalid.yaml");
throws_ok { App::ConfigMaker->run(qw(init -u)); } qr/YAML/, 'config.yaml having template_dir with invalid control.yaml on init';

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