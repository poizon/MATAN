package MTN::Printer::Manager;

use strict;

use base qw(Rose::DB::Object::Manager);
use lib qw(../..);
use MTN::Printer;

sub object_class { 'MTN::Printer' }

__PACKAGE__->make_manager_methods('printers');

1;

