package acaschema::Result::InteractionDomain;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("interaction_domain");
__PACKAGE__->add_columns(
  "interaction_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 11 },
  "domain_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 11 },
  "complex_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 10 },
);
__PACKAGE__->set_primary_key("interaction_id", "domain_id", "complex_id");
__PACKAGE__->belongs_to(
  "interaction_id",
  "acaschema::Result::Interaction",
  { id => "interaction_id" },
);
__PACKAGE__->belongs_to(
  "domain",
  "acaschema::Result::Domain",
  { complex_id => "complex_id", id => "domain_id" },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2010-11-05 13:48:04
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:tWb5GxJSScVAQ0Gw7iWNAw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
