package WebAPI::DBIC::Resource::GenericItem;
$WebAPI::DBIC::Resource::GenericItem::VERSION = '0.002000';

use Moo;
use namespace::clean;

extends 'WebAPI::DBIC::Resource::GenericCore';
with    'WebAPI::DBIC::Resource::Role::Item',
        'WebAPI::DBIC::Resource::Role::ItemWritable',
        # Enable HAL support:
        'WebAPI::DBIC::Resource::Role::DBIC_HAL',
        'WebAPI::DBIC::Resource::Role::ItemHAL',
        'WebAPI::DBIC::Resource::Role::ItemWritableHAL',
        # Enable JSON API support:
        'WebAPI::DBIC::Resource::Role::DBIC_JSONAPI',
        'WebAPI::DBIC::Resource::Role::ItemJSONAPI',
        'WebAPI::DBIC::Resource::Role::ItemWritableJSONAPI',
        ;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WebAPI::DBIC::Resource::GenericItem

=head1 VERSION

version 0.002000

=head1 NAME

WebAPI::DBIC::Resource::GenericItem - a set of roles to implement a generic DBIC item resource

=head1 AUTHOR

Tim Bunce <Tim.Bunce@pobox.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Tim Bunce.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
