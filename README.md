# Image Optimizer

This is a simple Ruby script that losslessly optimizes JPG, GIF and JPG files in a given directory, recursively.

The required tools are `gifsicle`, `jpegtran`, and `pngcrush.`

To run:

    ?> ruby optimize.rb dir/

A similar Rake task is included, but it only scans the ./public/images folder at this time.

    ?> rake optimize

or

    ?> bundle exec rake optimize

These scripts have only been tested under MacOS X.
