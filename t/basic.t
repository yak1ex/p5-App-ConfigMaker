use Test::More tests => 6;
use Test::Exception;

use FindBin;
use Pod::Usage;

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
