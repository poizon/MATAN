package MTN::Picture::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);
use lib qw(../..);
use MTN::Picture;

sub object_class { 'MTN::Picture' }

__PACKAGE__->make_manager_methods('pictures');

1;

