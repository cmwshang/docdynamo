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

use docDynamo::Common::Process::Execute;

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

    my $strLogo = $self->{oManifest}->variableGet('pdf-logo');

    if (!defined($strLogo))
    {
        $strLogo = 'blank.eps';
    }

    my ($strExt) = $strLogo =~ /(\.[^.]+)$/;
    my $strLogoPath = defined($self->{oManifest}->variableGet('pdf-logo-path')) ?
        $self->{oManifest}->variableGet('pdf-logo-path') :
        "$self->{oManifest}{strDocPath}/resource/latex/";

    # Copy the logo
    copy($strLogoPath . $strLogo, "$self->{strLatexPath}/logo$strExt")
        or confess &log(ERROR, "unable to copy logo");

    # Set the title variables for replacement in the doc
    if (defined($oRender->{title1}))
    {
        $self->{oManifest}->variableSet('main-title1', $oRender->{title1});
    }

    if (defined($oRender->{title2}))
    {
        $self->{oManifest}->variableSet('main-title2', $oRender->{title2});
    }

    if (defined($oRender->{title3}))
    {
        $self->{oManifest}->variableSet('main-title3', $oRender->{title3});
    }

    # Set the footer variables for replacement in the doc
    $self->{oManifest}->variableSet('footer-left', (defined($oRender->{'footer-left'}) ? $oRender->{'footer-left'} : '\\ '));
    $self->{oManifest}->variableSet('footer-center', (defined($oRender->{'footer-center'}) ? $oRender->{'footer-center'} : '\\ '));
    $self->{oManifest}->variableSet('footer-right', (defined($oRender->{'footer-right'}) ? $oRender->{'footer-right'} : '\\ '));

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

            # Set the  main titles from the first page if not already set in the manifest.xml
            $self->titleSet(\$strLatex, $oDocLatexSection, 'main-title1', 'title');
            $self->titleSet(\$strLatex, $oDocLatexSection, 'main-title2', 'subtitle');
            $self->titleSet(\$strLatex, $oDocLatexSection, 'main-title3', undef);

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

####################################################################################################################################
# titleSet
#
# Sets the variables for replacing the main titles
####################################################################################################################################
sub titleSet
{
    my $self = shift;

    # Assign function parameters, defaults, and log debug info
    my
    (
        $strOperation,
        $strLatex,
        $oDocSection,
        $strMainTitle,
        $strAttribute,
    ) =
        logDebugParam
        (
            __PACKAGE__ . '->titleSet', \@_,
            {name => 'strLatex'},
            {name => 'oDocSection'},
            {name => 'strMainTitle'},
            {name => 'strAttribute', required => false},
        );


    if (!$self->{oManifest}->variableTest($strMainTitle))
    {
        my $oPage = $oDocSection->{oDoc};

        my $strTitle;

        if (defined($strAttribute))
        {
            $strTitle = $oPage->paramGet($strAttribute, false);
        }

        # If one is not defined then enter a blank line
        if (!defined($strTitle))
        {
            $strTitle = '\\ ';
        }

        $self->{oManifest}->variableSet($strMainTitle, $strTitle);

        $$strLatex =~ s/\{\[$strMainTitle\]\}/$strTitle/g;
    }
}

1;
