package WebAPI::DBIC::Resource::Role::Set;
$WebAPI::DBIC::Resource::Role::Set::VERSION = '0.001008';

use Moo::Role;


requires 'encode_json';
requires 'render_set_as_plain';
requires 'render_set_as_hal';


sub allowed_methods { return [ qw(GET HEAD) ] }

sub content_types_provided { return [
    {'application/hal+json' => 'to_hal_json'},
    {'application/json'     => 'to_plain_json'},
] } 

sub to_plain_json { return $_[0]->encode_json($_[0]->render_set_as_plain($_[0]->set)) }
sub to_hal_json   { return $_[0]->encode_json($_[0]->render_set_as_hal(  $_[0]->set)) }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WebAPI::DBIC::Resource::Role::Set

=head1 VERSION

version 0.001008

=head1 DESCRIPTION

Handles GET and HEAD requests for requests representing set resources, e.g.
the rows of a database table.

Supports the C<application/hal+json> and C<application/json> content types.

=head1 NAME

WebAPI::DBIC::Resource::Role::Set - methods related to handling requests for set resources

=head1 AUTHOR

Tim Bunce <Tim.Bunce@pobox.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Tim Bunce.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
