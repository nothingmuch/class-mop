
package Class::MOP::Browser;

use strict;
use warnings;

use Class::MOP;
use B::Deparse;
use Data::Dumper;

use Catalyst::Runtime '5.70';
use Catalyst qw/
    -Debug  
/;

our $VERSION = '0.01';

__PACKAGE__->config(name => 'Class::MOP::Browser');

__PACKAGE__->config(
    'View::TT' => {
        INCLUDE_PATH => [
            __PACKAGE__->path_to(qw/root/),
            __PACKAGE__->path_to(qw/root templates/),            
        ],
        TEMPLATE_EXTENSION => ".tmpl",
        WRAPPER => [
            'wrappers/root.tmpl',
        ],
    },
);


__PACKAGE__->setup;

sub get_all_metaclasses   { sort { $a->name cmp $b->name } Class::MOP::get_all_metaclass_instances() }
sub get_metaclass_by_name { 
    shift;
    Class::MOP::get_metaclass_by_name(@_);   
}

sub deparse_method {
    my (undef, $method) = @_;
    
    my $deparse = B::Deparse->new("-d");
    my $body = $deparse->coderef2text($method->body());
    
    my @body = split /\n/ => $body;
    my @cleaned;
    
    foreach (@body) {
        next if /^\s+use/;
        next if /^\s+BEGIN/;        
        next if /^\s+package/;        
        push @cleaned => $_;
    }
    
    return "sub " . $method->name . ' ' . (join "\n" => @cleaned);
}

sub deparse_item {
    my (undef, $item) = @_;
    return $item unless ref $item;
    local $Data::Dumper::Deparse = 1;
    local $Data::Dumper::Indent  = 1;
    my $dumped = Dumper $item;    
    $dumped =~ s/^\$VAR1\s=\s//;
    $dumped =~ s/\;$//;    
    
    my @body = split /\n/ => $dumped;
    my @cleaned;
    
    foreach (@body) {
        next if /^\s+use/;
        next if /^\s+BEGIN/;        
        next if /^\s+package/;        
        push @cleaned => $_;
    }    
    
    return (join "\n" => @cleaned);
}


1;

__END__

=pod

=head1 NAME

Class::MOP::Browser - Catalyst based application

=head1 SYNOPSIS

    script/class_mop_browser_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<Class::MOP::Browser::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Stevan Little

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
