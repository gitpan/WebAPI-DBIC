package WebAPI::DBIC::Resource::GenericSetDBIC;
$WebAPI::DBIC::Resource::GenericSetDBIC::VERSION = '0.001003';
use Moo;
use namespace::clean;

extends 'WebAPI::DBIC::Resource::Base';
with    'WebAPI::DBIC::Role::JsonEncoder',
        'WebAPI::DBIC::Role::JsonParams',
        'WebAPI::DBIC::Resource::Role::DBIC',
        'WebAPI::DBIC::Resource::Role::DBICException',
        'WebAPI::DBIC::Resource::Role::DBICAuth',
        'WebAPI::DBIC::Resource::Role::DBICParams',
        'WebAPI::DBIC::Resource::Role::SetRender',
        'WebAPI::DBIC::Resource::Role::Set',
        'WebAPI::DBIC::Resource::Role::SetWritable',
        ;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WebAPI::DBIC::Resource::GenericSetDBIC

=head1 VERSION

version 0.001003

=head1 AUTHOR

Tim Bunce <Tim.Bunce@pobox.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Tim Bunce.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
