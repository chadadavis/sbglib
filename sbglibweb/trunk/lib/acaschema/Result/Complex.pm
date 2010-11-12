package acaschema::Result::Complex;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("InflateColumn::DateTime", "Core");
__PACKAGE__->table("complex");
__PACKAGE__->add_columns(
  "id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 10 },
  "model",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 2 },
  "network_id",
  { data_type => "INT", default_value => undef, is_nullable => 0, size => 10 },
  "score",
  { data_type => "FLOAT", default_value => undef, is_nullable => 1, size => 32 },
  "nreplaced",
  { data_type => "INT", default_value => 0, is_nullable => 0, size => 10 },
  "path",
  {
    data_type => "VARCHAR",
    default_value => undef,
    is_nullable => 1,
    size => 1024,
  },
);
__PACKAGE__->set_primary_key("id", "network_id");
__PACKAGE__->belongs_to(
  "network_id",
  "acaschema::Result::Network",
  { id => "network_id" },
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


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2010-11-05 13:48:04
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:hh7TtfmhDYrhHZRq0XqsbA


# You can replace this text with custom content, and it will be preserved on regeneration

use File::Spec::Functions;

sub basedir {
	my ($self) = @_;
	my $net = $self->network_id;
	my $part = sprintf "%02d", $net->partition;
	my $target = $net->target_id;
	my $exp = $target->experiment_id;
	my $model = sprintf "%02d", $self->model;
	return catdir($exp->label, $target->label, $part, $model); 
}

1;
