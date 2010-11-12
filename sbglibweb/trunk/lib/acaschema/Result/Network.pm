package acaschema::Result::Network;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("network");
__PACKAGE__->add_columns(
  "id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 10 },
  "target_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 10 },
  "partition",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 2 },
  "nnodes",
  { data_type => "INT", default_value => undef, is_nullable => 1, size => 10 },
  "ninteractions",
  { data_type => "INT", default_value => undef, is_nullable => 1, size => 10 },
  "nedges",
  { data_type => "INT", default_value => undef, is_nullable => 1, size => 10 },
);
__PACKAGE__->set_primary_key("id", "target_id");
__PACKAGE__->has_many(
  "complexes",
  "acaschema::Result::Complex",
  { "foreign.network_id" => "self.id" },
);
__PACKAGE__->belongs_to(
  "target_id",
  "acaschema::Result::Target",
  { id => "target_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2010-11-05 13:48:04
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:wipMsb6Wf6AEGeV5WAhxkA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
