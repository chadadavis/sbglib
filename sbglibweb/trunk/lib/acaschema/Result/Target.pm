package acaschema::Result::Target;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("target");
__PACKAGE__->add_columns(
  "id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 10 },
  "label",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 1,
    size => 128,
  },
  "description",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 1,
    size => 1024,
  },
  "notes",
  {
    data_type => "LONGTEXT",
    default_value => undef,
    is_nullable => 1,
    size => 4294967295,
  },
  "user",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 1,
    size => 128,
  },
  "experiment_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 10 },
);
__PACKAGE__->set_primary_key("id", "experiment_id");
__PACKAGE__->has_many(
  "networks",
  "acaschema::Result::Network",
  { "foreign.target_id" => "self.id" },
);
__PACKAGE__->belongs_to(
  "experiment_id",
  "acaschema::Result::Experiment",
  { id => "experiment_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2010-11-02 17:53:22
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:M1SVJs9CrQ4prPSA15Ktug


# You can replace this text with custom content, and it will be preserved on regeneration
1;
