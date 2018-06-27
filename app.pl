#!/usr/bin/env perl

use strict;
use warnings;

use Dancer2;
#use DBI;
#use Template;
use Data::Dumper;
use Imager;
use Util::Underscore;

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

our $api_key        = 'uKgMjIpeqXWPbVqdJXPFVdro4LUeXEvk';
our $root           = config->{appdir}.'/public';
our $image_dir      = 'uploads';
our $thumb_dir      = 'thumb';
our $website        = 'http://www.travellers-palm.com';

hook before_template_render => sub 
{
    my $tokens = shift;

    $tokens->{css_url} = request->base . 'css/';
    $tokens->{js_url}  = request->base . 'js/';
    $tokens->{img_url} = request->base . 'img/';
};

get '/' => sub {

    template 'index.tt';
};

del '/:deletes' => sub 
{   
    my $deletes = param('deletes');

    unlink path("root/$image_dir", $deletes);
    unlink path("$root/$image_dir/$thumb_dir", $deletes);

    my %response;
    $response{'files'} = { $deletes => 1 };

    return encode_json(\%response);
};

get '/upload' => sub 
{
    my ($json, @array, $error);

    if ( opendir( DIR, "$root/$image_dir" ) ) 
    {
        while ( my $filename = readdir(DIR) ) 
        {
            next if ( $filename =~ m/^\./ );
            next if ( $filename =~ m/thumb/); 

            $json = 
            {
                name            => $filename,
                size            => (-s $filename),
                url             => path("$image_dir", $filename),
                thumbnailUrl    => path("image_dir/$thumb_dir", $filename),
                deleteUrl       => $filename,
                deleteType      => "DELETE"
            };
            
            push( @array, $json );   
        };
        closedir(DIR);
    }
    else 
    {
        return template 'index.tt' => { $error => "The directory $image_dir is not on file" };
    };

    my %response;
    $response{'files'} = \@array;
    return encode_json(\%response);
};

post '/upload' => sub 
{
    my $uploads = request->uploads('files[]');
    my @array;
    my $json;
    my @uploads;
    
    mkdir path( $image_dir) if not -e path(  $image_dir );
    mkdir path("$image_dir/$thumb_dir") if not -e path( "$image_dir/$thumb_dir");

    unless (_::is_array_ref $uploads->{'files[]'})
    {
        push(@uploads,$uploads->{'files[]'});
        $uploads->{'files[]'} = \@uploads;
    } 

    for my $data ( @{ $uploads->{'files[]'} } ) {

        my $filename = $data->{filename};
       
        if (-e "$image_dir/$filename") 
        {
            $json = 
            {
                name  => $filename,
                size  => $data->{size},
                error => "$filename already exists in $image_dir"
            };
        } 
        else 
        {
            $json = 
            {
                name            => $filename,
                size            => $data->{size},
                url             => "$image_dir/$filename",
                thumbnailUrl    => path("$image_dir/$thumb_dir", $data->{filename}),
                deleteUrl       => $data->{filename},
                deleteType      => "DELETE"
            };

            $data->copy_to("$root/$image_dir/$filename");

            # compress the image by TinyPNG
            my $compressed = `curl https://api.tinify.com/shrink --user api:$api_key 
                            --data-binary "$website/$image_dir/$filename" --dump-header /dev/stdout`;


debug to_dumper($compressed);

#debug to_dumper( $compressed->{error});
    
            if ( $compressed =~ m/error/ )
            {
                $json = 
                {
                    name  => $filename,
                    size  => $data->{size},
                    error => "Issue compressing $website/$image_dir/$filename: $compressed"
                };
            }


            # generate the thumbbnail
            my $img = Imager->new;
               $img->read(file => "$root/$image_dir/$filename") 
                        or die "Cannot read $filename from file: ", $img->{errstr};
            my $thumbnail = $img->scale(xpixels=>80,ypixels=>80);
               $thumbnail->write(file => "$root/$image_dir/$thumb_dir/$filename") 
                        or die "Cannot save thumbnail $filename: ",$img->{errstr};
            
        };
        push( @array, $json );
    }
    
    my %response;
    $response{'files'} = \@array;

    return encode_json(\%response);
};

start;