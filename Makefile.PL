use inc::Module::Install;

name 'Class-MOP-Browser';
all_from 'lib/Class/MOP/Browser.pm';

requires 'Catalyst' => '5.7001';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Action::RenderView';
requires 'YAML'; # This should reflect the config file format you've chosen
                 # See Catalyst::Plugin::ConfigLoader for supported formats
catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
