#!perl
use strict;
use warnings;
use Test::More tests => 1;
use Archive::Extract;

foreach my $name qw(test-project test-project-packs) {
    next if -d $name;
    my $ae = Archive::Extract->new( archive => "$name.tgz" );
    $ae->extract;
}
ok(1, 'extracted');

=for shell

How to create test-project and test-project-packs:

mkdir test-project
cd test-project
git init
git config user.name "Your Name Comes Here"
git config user.email you@yourdomain.example.com
echo 'hello world' > file.txt
git add .
git commit -a -m "initial commit"
echo 'hello world!' >file.txt
git commit -a -m "add emphasis"
echo "hello world, again" >>file.txt
git commit -a -m "add again"
cd ..
tar fvzc test-project.tgz test-project

cd test-project
git gc
cd ..
mv test-project test-project-packs
tar fvzc test-project-packs.tgz test-project-packs
rm -rf test-project-packs

=cut 
