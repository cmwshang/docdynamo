####################################################################################################################################
# DOC MARKDOWN MODULE
####################################################################################################################################
package docDynamo::Markdown::DocMarkdown;

use strict;
use warnings FATAL => qw(all);
use Carp qw(confess);

use Data::Dumper;
use Exporter qw(import);
    our @EXPORT = qw();
use File::Basename qw(dirname);
use File::Copy;
use POSIX qw(strftime);
use Storable qw(dclone);

use docDynamo::Common::Log;
use docDynamo::Common::String;
use docDynamo::Version;

use docDynamo::Common::Process::Execute;

use docDynamo::Doc::DocManifest;
use docDynamo::Markdown::DocMarkdownRender;

####################################################################################################################################
# CONSTRUCTOR
####################################################################################################################################
sub new
{
    my $class = shift;       # Class name

    # Create the class hash
    my $self = {};
    bless $self, $class;

    $self->{strClass} = $class;

    # Assign function parameters, defaults, and log debug info
    (
        my $strOperation,
        $self->{oManifest},
        $self->{strXmlPath},
        $self->{strMarkdownPath},
        $self->{bExe}
    ) =
        logDebugParam
        (
            __PACKAGE__ . '->new', \@_,
            {name => 'oManifest'},
            {name => 'strXmlPath'},
            {name => 'strMarkdownPath'},
            {name => 'bExe'}
        );

    # Remove the current html path if it exists
    if (-e $self->{strMarkdownPath})
    {
        executeTest("rm -rf $self->{strMarkdownPath}/*");
    }
    # Else create the html path
    else
    {
        mkdir($self->{strMarkdownPath})
            or confess &log(ERROR, "unable to create path $self->{strMarkdownPath}");
    }

    # Return from function and log return values if any
    return logDebugReturn
    (
        $strOperation,
        {name => 'self', value => $self}
    );
}

####################################################################################################################################
# process
#
# Generate the site html
####################################################################################################################################
sub process
{
    my $self = shift;

    # Assign function parameters, defaults, and log debug info
    my $strOperation = logDebugParam(__PACKAGE__ . '->process');

    foreach my $strRenderOutId ($self->{oManifest}->renderOutList(RENDER_TYPE_MARKDOWN))
    {
        my $oRenderOut = $self->{oManifest}->renderOutGet(RENDER_TYPE_MARKDOWN, $strRenderOutId);
        my $strFile = "$self->{strMarkdownPath}/" . (defined($$oRenderOut{file}) ? $$oRenderOut{file} : "${strRenderOutId}.md");

        &log(INFO, "    render out: ${strRenderOutId}");

        # Save the markdown page
        $self->{oManifest}->storage()->put(
            $strFile, $self->{oManifest}->variableReplace((new docDynamo::Markdown::DocMarkdownRender($self->{oManifest},
            $strRenderOutId, $self->{bExe}))->process()));
    }

    # Return from function and log return values if any
    logDebugReturn($strOperation);
}

1;
