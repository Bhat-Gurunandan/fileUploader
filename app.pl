#!/usr/bin/env perl

use strict;
use warnings;

use Dancer2;
use DBI;
use Template;
use Imager;
# installation instructions:
# cpanm Imager Imager::File::JPEG
# sudo yum install libjpeg-devel (libjpeg-dev on Ubuntu)

set 'session'      => 'Simple';
set 'template'     => 'template_toolkit';
set 'logger'       => 'console';
set 'log'          => 'debug';
set 'show_errors'  => 1;
set 'startup_info' => 1;
set 'warnings'     => 1;
set 'layout'       => 'main';

our $image_path = 'uploads';
our $thumb_path = 'uploads/thumb';
our $root       =  config->{appdir}.'/public/';

hook before_template_render => sub {

    my $tokens = shift;

    $tokens->{css_url} = request->base . 'css/';
    $tokens->{js_url}  = request->base . 'js/';
    $tokens->{img_url} = request->base . 'img/';
};

get '/' => sub {

    template 'index.tt';
};

del '/:deletes' => sub {
   
    my $deletes = param('deletes');

    unlink path($root.$image_path, $deletes);
    unlink path($root.$thumb_path, $deletes);

    my %response;
    $response{'files'} = { $deletes => 1 };

    return encode_json(\%response);
};

get '/upload' => sub {
    my ($json, @array, $error);

    if ( opendir( DIR, $root.$image_path ) ) {
    
        while ( my $file = readdir(DIR) ) {
            next if ( $file =~ m/^\./ );
            next if ( $file =~ m/thumb/); 

            $json = {
                name            => $file,
                size            => (-s $file),
                url             => $image_path.$file,
                thumbnailUrl    => path($thumb_path, $file),
                deleteUrl       => $file,
                deleteType      => "DELETE"
            };
            
            push( @array, $json );   
        };
        closedir(DIR);
    }
    else {
        return template 'index.tt' => { $error => "The directory $image_path is not on file" };
    };

    my %response;
    $response{'files'} = \@array;
    return encode_json(\%response);
};

post '/upload' => sub {

    my $uploads = request->uploads('files[]');
    my @array;
    my $json;
    my @uploads;
    
    mkdir path( $root,$image_path) if not -e path( $root,$image_path);
    mkdir path( $root,$thumb_path) if not -e path( $root,$thumb_path);

    # use Data::Dumper;

    unless (ref $uploads->{'files[]'} eq 'ARRAY'){
        push(@uploads,$uploads->{'files[]'});
        $uploads->{'files[]'} = \@uploads;
    } 

    for my $file ( @{ $uploads->{'files[]'} } ) {

        my $path = path($root.$image_path, $file->{filename});



        if (-e $path) {
            $json = {
                name  => $file->{filename},
                size  => $file->{size},
                error => " File already exists in $image_path"
            };
        } 
        else {
            $json = {
                name            => $file->{filename},
                size            => $file->{size},
                url             => $file->{filename},
                thumbnailUrl    => path($thumb_path, $file->{filename}),
                deleteUrl       => $file->{filename},
                deleteType      => "DELETE"
            };

            $file->copy_to($path);

            # generate the thumbbnail
            my $img = Imager->new;
            $img->read(file=> $root.$image_path.'/'.$file->{filename}) 
                or die 'Cannot load '.$image_path.'/'.$file->{filename}.': ', $img->{errstr};
            my $thumbnail = $img->scale(xpixels=>80,ypixels=>80);
            $thumbnail->write(file=>$root.$thumb_path.'/'.$file->{filename}) 
                or die 'Cannot save thumbnail file '.$file->{filename},$img->{errstr};
        };
        push( @array, $json );
    }
    
    my %response;
    $response{'files'} = \@array;

    return encode_json(\%response);
};

start;
