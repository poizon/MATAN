package MTN::Object;

use lib qw(..);
use MTN::DB;
use base qw/Rose::DB::Object/;

sub init_db { MTN::DB->new() }

#__PACKAGE__->meta->make_manager_class;

1;
