package WebAPI::DBIC::Resource::Role::ItemWritable;
$WebAPI::DBIC::Resource::Role::ItemWritable::VERSION = '0.001005'; # TRIAL
use Carp qw(croak confess);
use Devel::Dwarn;

use Moo::Role;


requires 'render_item_into_body';
requires 'decode_json';
requires 'item';
requires 'param';
requires 'prefetch';
requires 'request';
requires 'response';
requires 'path_for_item';


sub content_types_accepted { return [
    {'application/hal+json' => 'from_plain_json'},
    {'application/json'     => 'from_plain_json'}
] }


sub from_plain_json { # XXX currently used for hal too
    my $self = shift;
    my $data = $self->decode_json( $self->request->content );
    $self->update_resource($data, is_put_replace => 0);
    return;
}


around 'allowed_methods' => sub {
    my $orig = shift;
    my $self = shift;
 
    my $methods = $self->$orig();

    push @$methods, qw(PUT DELETE) if $self->writable;

    return $methods;
};


sub delete_resource { return $_[0]->item->delete }


sub _update_embedded_resources {
    my ($self, $item, $hal, $result_class) = @_;

    my $links    = delete $hal->{_links};
    my $meta     = delete $hal->{_meta};
    my $embedded = delete $hal->{_embedded} || {};

    for my $rel (keys %$embedded) {

        my $rel_info = $result_class->relationship_info($rel)
            or die "$result_class doesn't have a '$rel' relation\n";
        die "$result_class _embedded $rel isn't a 'single' relationship\n"
            if $rel_info->{attrs}{accessor} ne 'single';

        my $rel_hal = $embedded->{$rel};
        die "_embedded $rel data is not a hash\n"
            if ref $rel_hal ne 'HASH';

        # work out what keys to copy from the subitem we're about to update
        # XXX this isn't required unless updating key fields - optimize
        my %fk_map;
        my $cond = $rel_info->{cond};
        for my $sub_field (keys %$cond) {
            my $our_field = $cond->{$sub_field};
            $our_field =~ s/^self\.//x    or confess "panic $rel $our_field";
            $sub_field =~ s/^foreign\.//x or confess "panic $rel $sub_field";
            $fk_map{$our_field} = $sub_field;

            die "$result_class already contains a value for '$our_field'\n"
                if defined $hal->{$our_field}; # null is ok
        }

        # update this subitem (and any resources embedded in it)
        my $subitem = $item->$rel();
        $subitem = $self->_update_embedded_resources($subitem, $rel_hal, $rel_info->{source});

        # copy the keys of the subitem up to the item we're about to update
        warn "$result_class $rel: propagating keys: @{[ %fk_map ]}\n"
            if $ENV{WEBAPI_DBIC_DEBUG};
        while ( my ($ourfield, $subfield) = each %fk_map) {
            $hal->{$ourfield} = $subitem->$subfield();
        }

        # XXX perhaps save $subitem to optimise prefetch handling?
    }

    # XXX discard_changes causes a refetch of the record for prefetch
    # perhaps worth trying to avoid the discard if not required
    return $item->update($hal)->discard_changes();
}


sub update_resource {
    my ($self, $hal, %opts) = @_;
    my $is_put_replace = delete $opts{is_put_replace};
    croak "update_resource: invalid options: @{[ keys %opts ]}"
        if %opts;

    my $schema = $self->item->result_source->schema;
    # XXX perhaps the transaction wrapper belongs higher in the stack
    # but it has to be below the auth layer which switches schemas
    $schema->txn_do(sub {

        my $item;
        if ($is_put_replace) {
            # PUT == http://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html#sec9.6

            # Using delete() followed by create() is a strict implementation
            # of treating PUT on an item as a REPLACE, but it might not be ideal.
            # Specifically it requires any FKs to be DEFERRED and it'll less
            # efficient than a simple UPDATE. There's also a concern that if
            # the REST API only has a partial view of the resource, ie not all
            # columns, then do we want the original deleted if the 'hidden'
            # fields can't be set?
            # So this could me made optional on a per-resource-class basis,
            # and/or via a request parameter.

            # we require PK fields to at least be defined
            # XXX we ought to check that they match the URL since a PUT is
            # required to store the entity "under the supplied Request-URI".
            # XXX throw proper exception
            defined $hal->{$_} or die "missing PK '$_'\n"
                for $self->set->result_source->primary_columns;

            my $old_item = $self->item; # XXX might already be gone since the find()
            $old_item->delete if $old_item; # XXX might already be gone since the find()

            my $links    = delete $hal->{_links};
            my $meta     = delete $hal->{_meta};
            my $embedded = delete $hal->{_embedded} && die "_embedded not supported here (yet?)\n";

            $item = $self->set->create($hal);

            $self->response->header('Location' => $self->path_for_item($item))
                unless $old_item; # set Location and thus 201 if Created not modified
        }
        else {
            $item = $self->_update_embedded_resources($self->item, $hal, $self->item->result_class);
        }

        # called here because create_path() is too late for WM
        # and we need it to happen inside the transaction for rollback=1 to work
        # XXX requires 'self' prefetch to get any others
        $self->render_item_into_body($item)
            if $item && $self->prefetch->{self};

        $schema->txn_rollback if $self->param('rollback'); # XXX
    });
    return;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WebAPI::DBIC::Resource::Role::ItemWritable

=head1 VERSION

version 0.001005

=head1 AUTHOR

Tim Bunce <Tim.Bunce@pobox.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Tim Bunce.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
