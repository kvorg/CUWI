#!/usr/bin/env perl
use Module::Build;

my $build = Module::Build->new
  (
   dist_name      => 'CWB::CUWI',
   dist_version_from => 'cuwi',
   dist_abstract  => 'Corpus Users\' Web Inteface with the CWB::Model backend',
   dist_author    => [
		      'Jan Jona Javorsek <jan.javorsek@guest.arnes.si>',
		      'Tomaz Erjavec <tomaz.erjavec@ijs.si>'
		     ],
   license        => 'perl',
   requires       => {
		      'perl'        => '5.10.1',
		      'Mojolicious' => '2.95',
		      'CWB::CQP'    => 0,
		     },
   build_requiers => {
		      'Software::Licence' => 0,
		     },
   script_files   => 'cuwi',
   test_files     => 't/*.t',
   sign           => 1,
   dynamic_config => 0,
   create_makefile_pl => 'passthrough',
  )->create_build_script;


