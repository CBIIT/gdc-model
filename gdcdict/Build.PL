use Module::Build;

my $build = Module::Build->new(
  distauthor => 'Mark A. Jensen',
  dist_version_from => 'lib/GDC/Dict.pm',
  dist_name => 'GDC-Dict',
  dist_abstract => 'Class for slurping GDC dictionaries',
  configure_requires => {
    'Module::Build' => 0
   },
  requires => {
    'YAML::PP' => 0,
    'JSON::XS' => 0,
    'Try::Tiny' => 0,
   },
  build_requires => {
    'Test::Warn' => 0,
  },
  perl => 5.010,

 );

$build->create_build_script;
