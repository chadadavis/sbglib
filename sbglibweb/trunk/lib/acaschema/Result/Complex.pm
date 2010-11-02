package acaschema::Result::Complex;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("complex");
__PACKAGE__->add_columns(
  "id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 10 },
  "network_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 10 },
  "target_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 10 },
);
__PACKAGE__->set_primary_key("id", "network_id", "target_id");
__PACKAGE__->belongs_to(
  "network",
  "acaschema::Result::Network",
  { id => "network_id", target_id => "target_id" },
);
__PACKAGE__->has_many(
  "domains",
  "acaschema::Result::Domain",
  { "foreign.complex_id" => "self.id" },
);
__PACKAGE__->has_many(
  "interactions",
  "acaschema::Result::Interaction",
  { "foreign.complex_id" => "self.id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2010-11-02 17:53:22
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Gt5Nv2QvJkeLRQ124crErQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
