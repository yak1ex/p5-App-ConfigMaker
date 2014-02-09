use Test::More tests => 10;
use Test::Exception;

use FindBin;
use Getopt::Config::FromPod;
Getopt::Config::FromPod->set_class_default(-file => 'bin/configmaker');

BEGIN {
use_ok('App::ConfigMaker');
}

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
