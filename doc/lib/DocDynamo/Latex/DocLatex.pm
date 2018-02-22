####################################################################################################################################
# DOC LATEX MODULE
####################################################################################################################################
package docDynamo::Latex::DocLatex;

use strict;
use warnings FATAL => qw(all);
use Carp qw(confess);
use English '-no_match_vars';

use Data::Dumper;
use Exporter qw(import);
    our @EXPORT = qw();
use File::Basename qw(dirname);
use File::Copy;
use POSIX qw(strftime);
use Storable qw(dclone);

use docDynamo::Common::Exception;
use docDynamo::Common::Log;
use docDynamo::Common::String;
use docDynamo::Version;

use pgBackRestTest::Common::ExecuteTest;

use docDynamo::Doc::DocConfig;
use docDynamo::Doc::DocManifest;
use docDynamo::Latex::DocLatexSection;

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
        $self->{strLatexPath},
        $self->{strPreambleFile},
        $self->{bExe}
    ) =
        logDebugParam
        (
            __PACKAGE__ . '->new', \@_,
            {name => 'oManifest'},
            {name => 'strXmlPath'},
            {name => 'strLatexPath'},
            {name => 'strPreambleFile'},
            {name => 'bExe'}
        );

    # Remove the current latex path if it exists
    if (-e $self->{strLatexPath})
    {
        executeTest("rm -rf $self->{strLatexPath}/*");
    }
    # Else create the html path
    else
    {
        mkdir($self->{strLatexPath})
            or confess &log(ERROR, "unable to create path $self->{strLatexPath}");
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
# Generate the pdf document
####################################################################################################################################
sub process
{
    my $self = shift;

    # Assign function parameters, defaults, and log debug info
    my $strOperation = logDebugParam(__PACKAGE__ . '->process');

    my $oRender = $self->{oManifest}->renderGet(RENDER_TYPE_PDF);

    # Copy the logo
    copy("$self->{oManifest}{strDocPath}/resource/latex/cds-logo.eps", "$self->{strLatexPath}/logo.eps")
        or confess &log(ERROR, "unable to copy logo");

    my $strLatex = $self->{oManifest}->variableReplace(
        ${$self->{oManifest}->storage()->get($self->{strPreambleFile})}, 'latex') . "\n";

    # ??? Temp hack for underscores in filename
    $strLatex =~ s/pgaudit\\\_doc/pgaudit\_doc/g;

    # Process the sources in the order listed in the manifest.xml
    foreach my $strPageId (@{${$self->{oManifest}->renderGet(RENDER_TYPE_PDF)}{stryOrder}})
    {
        &log(INFO, "    render out: ${strPageId}");

        eval
        {
            my $oDocLatexSection =
                new docDynamo::Latex::DocLatexSection($self->{oManifest}, $strPageId, $self->{bExe});

            if (defined($oRender->{title1})) { syswrite(*STDOUT, "Title1 DEFINED\n"); } # CSHANG Need to decide how to set main titles - basicall there should be a min title for a PDF document, for HTML pages (all) and for a MD document. This can come from the renderer title1 or if not specified, then take it from the page? but only the first one?

            # Retrieve the title and subtitle from the page
            my $oPage = $oDocLatexSection->{oDoc};

            # Initialize page title
            my $strTitle = $oPage->paramGet('title');
            my $strSubTitle = $oPage->paramGet('subtitle', false);

            $strLatex =~ s/\{\[pdf-title\]\}/$strTitle/g;

            # Add a subtitle if one is defined else enter a blank line
            if (!defined($strSubTitle))
            {
                $strSubTitle = '\\ ';
            }

            $strLatex =~ s/\{\[pdf-subtitle\]\}/$strSubTitle/g;

            # Save the html page
            $strLatex .= $oDocLatexSection->process();

            return true;
        }
        or do
        {
            my $oException = $EVAL_ERROR;

            if (exceptionCode($oException) == ERROR_FILE_INVALID)
            {
                my $oRenderOut = $self->{oManifest}->renderOutGet(RENDER_TYPE_HTML, $strPageId);
                $self->{oManifest}->cacheReset($$oRenderOut{source});

                my $oDocLatexSection =
                    new docDynamo::Latex::DocLatexSection($self->{oManifest}, $strPageId, $self->{bExe});

                # Save the html page
                $strLatex .= $oDocLatexSection->process();
            }
            else
            {
                confess $oException;
            }
        };
    }

    $strLatex .= "\n% " . ('-' x 130) . "\n% End document\n% " . ('-' x 130) . "\n\\end{document}\n";

    my $strLatexFileName = $self->{oManifest}->variableReplace("$self->{strLatexPath}/" . $$oRender{file} . '.tex');

    $self->{oManifest}->storage()->put($strLatexFileName, $strLatex);

    executeTest("pdflatex -output-directory=$self->{strLatexPath} -shell-escape $strLatexFileName",
                {bSuppressStdErr => true});
    executeTest("pdflatex -output-directory=$self->{strLatexPath} -shell-escape $strLatexFileName",
                {bSuppressStdErr => true});

    # Return from function and log return values if any
    logDebugReturn($strOperation);
}

1;
