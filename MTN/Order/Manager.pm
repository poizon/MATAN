package MTN::Order::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);
use lib qw(../..);
use MTN::Order;

sub object_class { 'MTN::Order' }

__PACKAGE__->make_manager_methods('orders');

1;

