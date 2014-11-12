package MTN::Option::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);
use lib qw(../..);
use MTN::Option;

sub object_class { 'MTN::Option' }

__PACKAGE__->make_manager_methods('options');

1;

