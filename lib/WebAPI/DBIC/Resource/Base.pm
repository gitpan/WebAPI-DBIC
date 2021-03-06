package WebAPI::DBIC::Resource::Base;
$WebAPI::DBIC::Resource::Base::VERSION = '0.003001'; # TRIAL

use Moo;
extends 'Web::Machine::Resource';

require WebAPI::HTTP::Throwable::Factory;


has http_auth_type => (
   is => 'ro',
   default => 'Basic',
);

has throwable => (
    is => 'rw',
    default => 'WebAPI::HTTP::Throwable::Factory',
);


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WebAPI::DBIC::Resource::Base

=head1 VERSION

version 0.003001

=head1 DESCRIPTION

This class is simply a pure subclass of WebAPI::DBIC::Resource.

=head1 NAME

WebAPI::DBIC::Resource::Base - Base class for WebAPI::DBIC::Resource's

=head1 AUTHOR

Tim Bunce <Tim.Bunce@pobox.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Tim Bunce.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
