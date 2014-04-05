package MultiSkan;

use 5.016;
use warnings;
use Carp;
use Moose;
use Statistics::Lite qw(mean stddev);
use Chart::ErrorBars;
use GD;

=head1 NAME

MultiSkan - The great new MultiSkan!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Used Multiskan™ FC Microplate Photometer (Thermo Scientific) for your experiment?Just got a text file as your output? Thinking it would be good if it had an app to give you an overview of all wells, and to help to group the data and do some simple stats for you? 
GOOD! That means I'm not alone. This module does some simple tasks for you...

    use MultiSkan;
    
    my @groups = (
        'amp', 'A2B2C2',
        'tet', 'A4B4C4',
        'Blank', 'A1B1C1',
 
    );
    my $data_file = 'GrowthCurve.TXT';
    open my $fh, '<', $data_file;
    my $ms = MultiSkan->new(fh => $fh);
    my $A1 = $ms->A1; # quering well A1
You can use
    my %data = $ms->group_stats(@groups); 
to get the averages and standard deviations for each groups.
Well, you can use `my @groups = qw/.../`, but then you lose the ability to comment out the groups you don't want for the final report...
 
If you want to write the data to a file to be processed by other apps (which usually require the data to be arranged in a column-wise fashion, then you can use this snippet:
    
    my @time = @{$ms->time};
    @time = map {$_/60} @time;
 
    my %data = $ms->group_stats(@groups);
 
    open my $oh, '>', 'report.txt';
 
    print $oh "time";
 
    for (my $i=0;$i<@groups;$i+=2){
        print $oh "\t$groups[$i]\tStdev";
    }
 
    print $oh "\n";
 
 
    for my $i (0..$#time){
        print $oh $time[$i];
        for (my $g=0;$g<@groups;$g+=2){
 
        print $oh "\t".$data{$groups[$g]}->{average}[$i]."\t".$data{$groups[$g]}->{stddev}[$i];
        }
        print $oh "\n";
    }
 
You can use the following function to draw an overview to check out all the 96 wells in a glimpse.
 
    $ms->draw_all_curves('all_curves.png');

All you can draw a selected set of data with averages and error bars...
    my %data = $ms->group_stats(@groups);
    $ms->draw_curves(
        'out_img' => 'curves.png',
        'height'  => 768,
        'width'   => 1024,
        'time'    => \@time,
        'data'    => \%data,
        'parameters' => {
            'min_val' => 0,
            'max_val' => 10,
            ...
    );

Since `draw_curves` uses `Chart::ErrorBars' to draw the curves, you can pass all the valid `Chart::ErrorBars' parameters as part of the `parameters` argument. 



=head1 SUBROUTINES/METHODS

=cut
# Populating wells
my @wells;

{
    my @rolls = 'A'..'H';
    my @lanes = 1..12;
    
    for my $roll (@rolls){
        push @wells, "$roll$_" for @lanes;
    }
}

# This is the file handle to the MultiSkan file
has 'fh' => (
    is          => 'rw',
    isa         => 'FileHandle',
    required    => 1,
);

# This is the 'time' vector from the MultiSkan file.
has 'time' => (
    is          => 'ro',
    lazy        => 1,
    builder     => '_build_time',
);

# To populate well data, so that you can use $ms->A1 to query for each well.
for my $well (@wells){
    has $well => (
        is      => 'ro',
        lazy    => 1,
        default => sub {
            my $self = shift;
            my $fh = $self->fh;
            seek $fh, 0, 0;
            my @lines = <$fh>;
            my ($line) = grep {/^$well/} @lines;
            my @line = split ' ', $line;
            shift @line;
            return [@line];
        },
    );
}

sub _build_time {
    my $self = shift;
    my $fh = $self->fh;
    seek $fh, 0, 0;
    my ($time_line) = grep {/^Time/} <$fh>;
    my @time = split /\t/, $time_line;
    shift @time;
    return [@time];
}

=head2 function2

=cut

sub group_stats {
    my $self = shift;
    my %groups = @_;
    
    my $fh = $self->fh;
    seek $fh, 0, 0;
    my @lines = <$fh>;
    
    # All the data will be stored here
    my %data;
    for my $k (keys %groups){
        
        # Group specific data will be stored here
        my %g_data;
        
        my $temp = $groups{$k};
        my $length;
        while ($temp =~ s/^(\w\d+)//){
            my $cell = $1;
            my $line;
            eval {$line = $self->$cell};
            croak "Invalid well: $cell" if $@;
            $length = @$line;
            $g_data{$cell} = $line;
        }
        croak "Invalid grouping! Group like this: 'A1B1C1', 'A2B2C2'." if $temp;
        
        for (0..$length-1){
            my @data;
            for my $key (keys %g_data){
                push @data, $g_data{$key}[$_];
            }
            push @{$data{$k}->{'average'}}, mean @data;
            push @{$data{$k}->{'stddev'}}, stddev @data;
        }
    }
    return %data;
}

sub draw_all_curves {
    my $self = shift;
    my $out_file = shift;
    my $count = 0;
    my $chart = GD::Image->new(1500,700);
    my @time = @{$self->time};
    my $white = $chart->colorAllocate(255,255,255);
    #$chart->transparent($white);
    $chart->interlaced('true');
    my $red = $chart->colorAllocate(255,0,0);
    my $blue = $chart->colorAllocate(0,0,255);
    for my $well (@wells) {
        my @data = @{$self->$well};
        my $h_gap = ($count%12)*120;
        my $v_gap = (int($count/12))*81;
        my $max = 1.5;
        for my $i (0..$#time){
            my $x = 5 + $i;
            my $y = 80 * $data[$i] / $max;
            $y = int(5 + 80 - $y);
            $chart->setPixel($x+$h_gap, $y+$v_gap, $red);
            $chart->string(gdSmallFont, $h_gap+40, $v_gap+60, $well, $blue);
        }
        $count++;
    }
    open my $oh, '>', $out_file;
    binmode $oh;
    print $oh $chart->png;
}

sub draw_curves {
    my $self = shift;
    # Any Chart::ErrorBars parameters can be passed along.
    my %arg = @_;
    # out_img and data are required!
    
    croak "out_img has to be provided!" unless $arg{out_img};
    croak "where are the data?" unless $arg{data};
    
    my $length = keys %{$arg{data}};
    # Setting some defaults;
    $arg{height} ||= 600;
    $arg{width}  ||= 800;
    $arg{'time'} ||= $self->time;
    my @labels = (sort keys %{$arg{data}});
    $arg{parameters}{legend_labels} ||= \@labels;
    $arg{parameters}{xy_plot} ||= 1;
    $arg{parameters}{min_val} ||=-0.2;
    $arg{parameters}{max_val} ||=2;
    $arg{parameters}{max_x_ticks} ||=5;
    $arg{parameters}{precision} ||= 1;
    $arg{parameters}{brush_size} ||=3;
    $arg{parameters}{pt_size} ||= 6;
    
    my $chart = Chart::ErrorBars->new($arg{width},$arg{height});
    my %par = %{$arg{parameters}};
    $chart->set(%par);
    
    my $time = $arg{'time'};
    my @data = ($time);
    
    # Add the real data
    for my $g (@labels){
        push @data,$arg{data}{$g}{average};
        my (@minus,@plus);
        push @data,($arg{data}{$g}{stddev},$arg{data}{$g}{stddev});
    }
    
    my $file = $arg{out_img};
    $chart->png($file, \@data);
}

=head1 AUTHOR

Jing, C<< <logust79 at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-multiskan at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=MultiSkan>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc MultiSkan


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=MultiSkan>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/MultiSkan>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/MultiSkan>

=item * Search CPAN

L<http://search.cpan.org/dist/MultiSkan/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2014 Jing.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

123; # End of MultiSkan
