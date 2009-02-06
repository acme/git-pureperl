#!perl
use strict;
use warnings;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME         => 'Git::PurePerl',
    VERSION_FROM => 'lib/Git/PurePerl.pm',
    AUTHOR       => 'Leon Brocard <acme@astray.com>',
    ABSTRACT     => 'A Pure Perl interface to Git repositories',
    LICENSE      => 'perl',
    PREREQ_PM    => {
        'Archive::Extract'           => '0',
        'Compress::Raw::Zlib'        => '0',
        'Compress::Zlib'             => '0',
        'Data::Stream::Bulk'         => '0',
        'Digest::SHA1'               => '0',
        'Moose'                      => '0',
        'MooseX::StrictConstructor'  => '0',
        'MooseX::Types::Path::Class' => '0',
    }
);

