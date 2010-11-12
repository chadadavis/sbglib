package acaschema::Result::Interaction;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("interaction");
__PACKAGE__->add_columns(
  "id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 11 },
  "complex_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 10 },
);
__PACKAGE__->set_primary_key("id", "complex_id");
__PACKAGE__->belongs_to(
  "complex_id",
  "acaschema::Result::Complex",
  { id => "complex_id" },
);
__PACKAGE__->has_many(
  "interaction_domains",
  "acaschema::Result::InteractionDomain",
  { "foreign.interaction_id" => "self.id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2010-11-05 13:48:04
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:8ioEk6jyMAhk+yl9pHZykw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
