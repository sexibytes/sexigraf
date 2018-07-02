<?php
session_start();
$title = "SexiGraf Export / Import";
require("header.php");
require("helper.php");
$tempMountOutput = shell_exec("sudo /bin/bash /var/www/scripts/automountCD.sh");
?>
    <div class="container"><br/>
        <div class="panel panel-default">
            <div class="panel-heading"><h3 class="panel-title">Export/Import Notes</h3></div>
            <div class="panel-body">
                <ul>
                    <li>The export process will generate an ISO file with your appliance configuration.</li>
                    <li>You will be able to download this ISO that will let you map it to another appliance to import data onto it.</li>
                    <li>In order to import data to this appliance, just map the ISO to its CD drive and use the Import tool below.</li>
                    <li>Please refer to the <a href="http://www.sexigraf.fr/">project website</a> and documentation for more information.</li>
                </ul>
            </div>
        </div>
        <h2><span class="glyphicon glyphicon-transfer" aria-hidden="true"></span> SexiGraf Export/Import</h2>
        <h3><span class="glyphicon glyphicon-export" aria-hidden="true"></span> Export</h3>
<?php if (file_exists('/var/www/admin/sexigraf-dump.iso')) : ?>
        <div class="alert alert-success" role="alert">
            <span class="glyphicon glyphicon-ok" aria-hidden="true"></span>
            <span class="sr-only">Success:</span>
            SexiGraf export file generated, you can download it here: <strong><a href="/admin/sexigraf-dump.iso">sexigraf-dump.iso</a></strong>
        </div>
<?php endif; ?>
<?php
$psList = shell_exec("ps auxwww | awk 'NR==1 || /exportSexiGrafBundle.sh/' | egrep -v 'awk|\/bin\/sh|sudo'");
$processes = explode("\n", trim($psList));
$nbProcess = count($processes);
if ($nbProcess == 1) : ?>
        <div class="alert alert-warning" role="alert">
            <span class="glyphicon glyphicon-refresh" aria-hidden="true"></span>
            <span class="sr-only">Warning:</span>
            SexiGraf export process is still running, please wait for a few minutes and refresh the page...
        </div>
<?php else : ?>
        <form class="form" action="export-import.php" method="post">
            <button name="submit" class="btn btn-success" value="genexport">Generate export bundle</button>
        </form>
<?php endif; ?>
        <h3><span class="glyphicon glyphicon-import" aria-hidden="true"></span> Import</h3>
<?php if (file_exists('/media/cdrom/dump.info')) : ?>
        <div class="alert alert-success" role="alert">
            <span class="glyphicon glyphicon-ok" aria-hidden="true"></span>
            <span class="sr-only">Success:</span>
            Valid SexiGraf export found: <strong><?php echo file_get_contents('/media/cdrom/dump.info', FILE_USE_INCLUDE_PATH); ?></strong>
        </div>
        <form class="form" action="export-import.php" method="post">
            <button name="submit" class="btn btn-success" value="runimport">Run import process</button>
        </form>
<?php else : ?>
        <div class="alert alert-danger" role="alert">
            <span class="glyphicon glyphicon-remove" aria-hidden="true"></span>
            <span class="sr-only">Error:</span>
            No valid SexiGraf export found, please mount ISO file generated from another SexiGraf appliance and try again.</strong>
        </div>
<?php endif; ?>
    </div>
    <script type="text/javascript" src="js/bootstrap.min.js"></script>
</body>
</html>
