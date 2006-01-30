
package BinaryTree;

use strict;
use warnings;

our $VERSION = '0.01';

use Class::MOP ':universal';

__PACKAGE__->meta->add_attribute(
    Class::MOP::Attribute->new('_uid' => (
        reader => 'getUID',
        writer => 'setUID',
        default => sub { 
            my $instance = shift;
            ("$instance" =~ /\((.*?)\)$/);
        }
    ))
);

__PACKAGE__->meta->add_attribute(
    Class::MOP::Attribute->new('_node' => (
        reader   => 'getNodeValue',
        writer   => 'setNodeValue',
        init_arg => ':node'
    ))
);

__PACKAGE__->meta->add_attribute(      
    Class::MOP::Attribute->new('_parent' => (
        reader    => 'getParent',
        writer    => 'setParent',
        predicate => {
            'isRoot' => sub {
            	my ($self) = @_;
            	return not defined $self->{_parent};                    
            }
        }
    ))
);

__PACKAGE__->meta->add_attribute(
    Class::MOP::Attribute->new('_left' => (
        predicate => 'hasLeft',         
        reader    => 'getLeft',
        writer => { 
            'setLeft' => sub {
                my ($self, $tree) = @_;
            	$tree->setParent($self);
                $self->{_left} = $tree;
                $tree->setDepth($self->getDepth() + 1);    
                $self;                    
            }
       },
    ))
);

__PACKAGE__->meta->add_attribute(  
    Class::MOP::Attribute->new('_right' => (
        predicate => 'hasRight',           
        reader    => 'getRight',
        writer => {
            'setRight' => sub {
                my ($self, $tree) = @_;   
            	$tree->setParent($self);
                $self->{_right} = $tree;    
                $tree->setDepth($self->getDepth() + 1);    
                $self;                    
            }
        }
    ))
);

__PACKAGE__->meta->add_attribute(            
    Class::MOP::Attribute->new('_depth' => (
        default => 0,
        reader  => 'getDepth',
        writer  => {
            'setDepth' => sub {
                my ($self, $depth) = @_;
                unless ($self->isLeaf()) {
                    $self->fixDepth();
                }
                else {
                    $self->{_depth} = $depth; 
                }                    
            }
        }
    ))
);

sub new {
    my $class = shift;
    bless $class->meta->construct_instance(':node' => shift) => $class;            
}    
        
sub removeLeft {
    my ($self) = @_;
    my $left = $self->{_left};
    $left->setParent(undef);   
    $left->setDepth(0);
    $self->{_left} = undef;     
    return $left;
}

sub removeRight {
    my ($self) = @_;
    my $right = $self->{_right};
    $right->setParent(undef);   
    $right->setDepth(0);
    $self->{_right} = undef;    
    return $right;
}
             
sub isLeaf {
	my ($self) = @_;
	return (!$self->hasLeft && !$self->hasRight);
}

sub fixDepth {
	my ($self) = @_;
	# make sure the tree's depth 
	# is up to date all the way down
	$self->traverse(sub {
			my ($tree) = @_;
            unless ($tree->isRoot()) {
                $tree->{_depth} = $tree->getParent()->getDepth() + 1;            
            }
            else {
                $tree->{_depth} = 0;
            }
		}
	);
}
     
sub traverse {
	my ($self, $func) = @_;
    $func->($self);
    $self->{_left}->traverse($func) if defined $self->{_left};    
    $self->{_right}->traverse($func) if defined $self->{_right};
}

sub mirror {
    my ($self) = @_;
    # swap left for right
    my $temp = $self->{_left};
    $self->{_left} = $self->{_right};
    $self->{_right} = $temp;
    # and recurse
    $self->{_left}->mirror() if $self->hasLeft();
    $self->{_right}->mirror() if $self->hasRight();
    $self;
}

sub size {
    my ($self) = @_;
    my $size = 1;
    $size += $self->{_left}->size() if $self->hasLeft();
    $size += $self->{_right}->size() if $self->hasRight();    
    return $size;
}

sub height {
    my ($self) = @_;
    my ($left_height, $right_height) = (0, 0);
    $left_height = $self->{_left}->height() if $self->hasLeft();
    $right_height = $self->{_right}->height() if $self->hasRight();    
    return 1 + (($left_height > $right_height) ? $left_height : $right_height);
}                      

