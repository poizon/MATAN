#!/usr/bin/perl -w

use common::sense;
use Rose::DB::Object::Loader;

my $loader = 
    Rose::DB::Object::Loader->new(
      db_dsn       => 'dbi:mysql:dbname=web;host=qiwi.giftec.ru',
      db_username  => 'web',
      db_password  => 'web',
      db_options   => { AutoCommit => 1, ChopBlanks => 1, mysql_enable_utf8 => 1 },
      class_prefix => 'MTN');
    
  $loader->make_modules(module_dir => 'd:\Dropbox\GIT\MATAN\MTN2');