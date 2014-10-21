package WebAPI::DBIC::Resource::Role::Item;
$WebAPI::DBIC::Resource::Role::Item::VERSION = '0.001007';

use Moo::Role;


requires 'render_item_as_plain_hash';
requires 'render_item_as_hal_hash';
requires 'id_unique_constraint_name';
requires 'encode_json';
requires 'set';


has id => (         # array of 1 or more key values from url path
   is => 'ro',
   #isa => array ref
   required => 1,
);

has item => (
   is => 'ro',
   lazy => 1,
   builder => '_build_item'
);

sub _build_item {
    my $self = shift;
    return $self->set->find( @{ $self->id }, { key => $self->id_unique_constraint_name } );
}


sub content_types_provided { return [
    {'application/hal+json' => 'to_json_as_hal'},
    {'application/json'     => 'to_json_as_plain'},
] }

sub to_json_as_plain { return $_[0]->encode_json($_[0]->render_item_as_plain_hash($_[0]->item)) }
sub to_json_as_hal {   return $_[0]->encode_json($_[0]->render_item_as_hal_hash($_[0]->item)) }

sub resource_exists { return !! $_[0]->item }

sub allowed_methods { return [ qw(GET HEAD) ] }


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WebAPI::DBIC::Resource::Role::Item

=head1 VERSION

version 0.001007

=head1 DESCRIPTION

Handles GET and HEAD requests for requests representing individual resources,
e.g. a single row of a database table.

Supports the C<application/hal+json> and C<application/json> content types.

=head1 NAME

WebAPI::DBIC::Resource::Role::Item - methods related to handling requests for item resources

=head1 AUTHOR

Tim Bunce <Tim.Bunce@pobox.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Tim Bunce.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
