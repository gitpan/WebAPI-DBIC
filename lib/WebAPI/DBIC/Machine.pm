package WebAPI::DBIC::Machine;
$WebAPI::DBIC::Machine::VERSION = '0.001003';
use Sub::Quote 'quote_sub';

use Moo;
use namespace::clean;

extends 'Web::Machine';

has debris => (
   is => 'ro',
   default => quote_sub q{ {} },
);

sub create_resource {
    my ($self, $request) = @_;
    return $self->{'resource'}->new(
        request  => $request,
        response => $request->new_response,
        %{ $self->debris },
    );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WebAPI::DBIC::Machine

=head1 VERSION

version 0.001003

=head1 AUTHOR

Tim Bunce <Tim.Bunce@pobox.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Tim Bunce.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
