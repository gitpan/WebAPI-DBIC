package WebAPI::DBIC::Resource::GenericRoot;
$WebAPI::DBIC::Resource::GenericRoot::VERSION = '0.002003';

use Moo;
use namespace::clean;

extends 'WebAPI::DBIC::Resource::Base';
with    'WebAPI::DBIC::Role::JsonEncoder',
        'WebAPI::DBIC::Resource::Role::Router',
        'WebAPI::DBIC::Resource::Role::DBICException',
        # for application/hal+json
        'WebAPI::DBIC::Resource::Role::Root',
        'WebAPI::DBIC::Resource::Role::RootHAL',
        ;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WebAPI::DBIC::Resource::GenericRoot

=head1 VERSION

version 0.002003

=head1 NAME

WebAPI::DBIC::Resource::GenericRoot - a set of roles to implement a 'root' resource describing the application

=head1 AUTHOR

Tim Bunce <Tim.Bunce@pobox.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Tim Bunce.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
