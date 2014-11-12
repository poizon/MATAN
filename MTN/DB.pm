package MTN::DB;

use base qw/Rose::DB/;
##
MTN::DB->use_private_registry;

MTN::DB->register_db
(
  #connect_options => { AutoCommit => 1, ChopBlanks => 1 , mysql_enable_utf8 => 1},
  driver          => 'fake',
  dsn             => 'dbi:fake:dbname=fake;host=fake',
  password        => 'fake',
  username        => 'fake',
);



1;
