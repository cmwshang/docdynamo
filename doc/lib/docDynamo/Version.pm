####################################################################################################################################
# VERSION MODULE
#
# Contains BackRest version and format numbers.
####################################################################################################################################
package docDynamo::Version;

use strict;
use warnings FATAL => qw(all);

use Cwd qw(abs_path);
use Exporter qw(import);
    our @EXPORT = qw();

# Project Name and version.
#
# Defines the official project name and current version.
#-----------------------------------------------------------------------------------------------------------------------------------
use constant DOCDYNAMO_NAME                                          => 'docDynamo';
    push @EXPORT, qw(DOCDYNAMO_NAME);
use constant DOCDYNAMO_VERSION                                       => '2.00dev';
    push @EXPORT, qw(DOCDYNAMO_VERSION);

1;
