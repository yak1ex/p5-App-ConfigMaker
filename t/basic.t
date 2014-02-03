use Test::More tests => 3;
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
