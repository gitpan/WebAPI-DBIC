package WebAPI::DBIC::Resource::Role::SetRender;
$WebAPI::DBIC::Resource::Role::SetRender::VERSION = '0.001008';


use Devel::Dwarn;
use Carp qw(confess);

use Moo::Role;


requires 'render_item_as_plain_hash';
requires 'render_item_as_hal_hash';
requires 'uri_for';
requires 'param';
requires 'add_params_to_url';


# Avoid complaints about $set:
## no critic (NamingConventions::ProhibitAmbiguousNames)

sub render_set_as_plain {
    my ($self, $set) = @_;
    my $set_data = [ map { $self->render_item_as_plain_hash($_) } $set->all ];
    return $set_data;
}


sub render_set_as_hal {
    my ($self, $set) = @_;

    # some params mean we're not returning resource representations
    # so render the contents of the _embedded set as plain JSON
    my $render_meth = ($self->param('distinct'))
        ? 'render_item_as_plain_hash'
        : 'render_item_as_hal_hash';
    my $set_data = [ map { $self->$render_meth($_) } $set->all ];

    my $total_items;
    if (($self->param('with')||'') =~ /count/) { # XXX
        $total_items = $set->pager->total_entries;
    }

    # XXX should $self->set here be $set?
    my ($prefix, $rel) = $self->uri_for(result_class => $self->set->result_class);
    my $data = {
        _embedded => {
            $rel => $set_data,
        },
        _links => {
            $self->_hal_page_links($set, "$prefix/$rel", scalar @$set_data, $total_items),
        }
    };
    $data->{_meta}{count} = $total_items
        if defined $total_items;

    return $data;
}


sub _hal_page_links {
    my ($self, $set, $base, $page_items, $total_items) = @_;

    # XXX we ought to allow at least the self link when not pages
    return () unless $set->is_paged;

    # XXX we break encapsulation here, sadly, because calling
    # $set->pager->current_page triggers a "select count(*)".
    # XXX When we're using a later version of DBIx::Class we can use this:
    # https://metacpan.org/source/RIBASUSHI/DBIx-Class-0.08208/lib/DBIx/Class/ResultSet/Pager.pm
    # and do something like $rs->pager->total_entries(sub { 99999999 })
    my $rows = $set->{attrs}{rows} or confess "panic: rows not set";
    my $page = $set->{attrs}{page} or confess "panic: page not set";

    # XXX this self link this should probably be subtractive, ie include all
    # params by default except any known to cause problems
    my $url = $self->add_params_to_url($base, { distinct=>1, with=>1, me=>1 }, { rows => $rows });
    my $linkurl = $url->as_string;
    $linkurl .= "&page="; # hack to optimize appending page 5 times below

    my @link_kvs;
    push @link_kvs, self  => {
        href => $linkurl.($page),
        title => $set->result_class,
    };
    push @link_kvs, next  => { href => $linkurl.($page+1) }
        if $page_items == $rows;
    push @link_kvs, prev  => { href => $linkurl.($page-1) }
        if $page > 1;
    push @link_kvs, first => { href => $linkurl.1 }
        if $page > 1;
    push @link_kvs, last  => { href => $linkurl.$set->pager->last_page }
        if $total_items and $page != $set->pager->last_page;

    return @link_kvs;
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WebAPI::DBIC::Resource::Role::SetRender

=head1 VERSION

version 0.001008

=head1 NAME

WebAPI::DBIC::Resource::Role::SetRender - methods for rendering resources as JSON

=head1 AUTHOR

Tim Bunce <Tim.Bunce@pobox.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Tim Bunce.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
