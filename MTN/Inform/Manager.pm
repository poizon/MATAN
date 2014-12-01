package MTN::Inform::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);
use lib qw(../..);
use MTN::Inform;

sub object_class { 'MTN::Inform' }

__PACKAGE__->make_manager_methods('inform');

1;

