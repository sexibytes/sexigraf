<?php
session_start();
$title = "SexiGraf Export/Import";
require("header.php");
require("helper.php");
$tempMountOutput = shell_exec("sudo /bin/bash /var/www/scripts/automountCD.sh");
if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    switch ($_POST["submit"]) {
        case "genexport":
            shell_exec("nohup sudo /bin/bash /var/www/scripts/exportSexiGrafBundle.sh > /dev/null 2>/dev/null &");
            sleep(1);
            break;
        case "runimport":
            shell_exec("nohup sudo /bin/bash /var/www/scripts/importSexiGrafBundle.sh > /dev/null 2>/dev/null &");
            sleep(1);
            break;
    }
}

?>
    <div class="container"><br/>
        <div class="panel panel-default">
            <div class="panel-heading"><h3 class="panel-title">Export/Import Notes</h3></div>
            <div class="panel-body">
                <ul>
                    <li>The export process will generate an <b>ISO file with your appliance configuration and data IF you got enough free space left</b>.</li>
                    <li>When done, download this ISO and use it to migrate your SexiGraf environement to another brand new SexiGraf VM.</li>
                    <li>In order to import data on this appliance, just map the ISO on the VM's CD drive and use the Import tool below.</li>
                    <li>Please refer to the <a href="https://www.sexigraf.fr/web-admin/#export-import">project website and documentation</a> for more information.</li>
                </ul>            
        </div>
        </div>
        <h2><span class="glyphicon glyphicon-transfer" aria-hidden="true"></span> SexiGraf Export/Import</h2>
	<br />
        <h3><span class="glyphicon glyphicon-export" aria-hidden="true"></span> Export</h3>
<?php
$psList = shell_exec("ps auxwww | awk 'NR==1 || /exportSexiGrafBundle.sh/' | egrep -v 'awk|\/bin\/sh|sudo'");
$processes = explode("\n", trim($psList));
$nbProcess = count($processes);
if ($nbProcess > 1) : ?>
        <div class="alert alert-warning" role="alert">
            <span class="glyphicon glyphicon-refresh" aria-hidden="true"></span>
            <span class="sr-only">Warning:</span>
            SexiGraf export process is still running, please wait for a few minutes and refresh the page...
        </div>
        <input type="button" class="btn btn-warning" value="Refresh Page" onClick="window.location.href = window.location.protocol +'//'+ window.location.host + window.location.pathname;">
<?php else : ?>
<?php if (file_exists('/var/www/admin/sexigraf-dump.iso')) : ?>
        <div class="alert alert-success" role="alert">
            <span class="glyphicon glyphicon-ok" aria-hidden="true"></span>
            <span class="sr-only">Success:</span>
            SexiGraf export file generated on <?php echo date ("r", filemtime('/var/www/admin/sexigraf-dump.iso')); ?>, you can download it here: <strong><a href="/sexiadmin/sexigraf-dump.iso">sexigraf-dump.iso</a></strong>
        </div>
<?php else : ?>
<div class="alert alert-warning" role="alert">
    <span class="glyphicon glyphicon-remove" aria-hidden="true"></span>
    <span class="sr-only">Info:</span>
    No ISO file generated yet...
</div>
<?php endif; ?>
	<form class="form" action="export-import.php" method="post">
            <button name="submit" class="btn btn-success" value="genexport">Generate export bundle</button>
        </form>
<?php endif; ?>
	<br />
        <h3><span class="glyphicon glyphicon-import" aria-hidden="true"></span> Import</h3>
    <?php
$psList = shell_exec("ps auxwww | awk 'NR==1 || /importSexiGrafBundle.sh/' | egrep -v 'awk|\/bin\/sh|sudo'");
$processes = explode("\n", trim($psList));
$nbProcess = count($processes);
if ($nbProcess > 1) : ?>
        <div class="alert alert-warning" role="alert">
            <span class="glyphicon glyphicon-refresh" aria-hidden="true"></span>
            <span class="sr-only">Warning:</span>
            SexiGraf import process is still running, please wait for a few minutes and refresh the page...
        </div>
        <input type="button" class="btn btn-warning" value="Refresh Page" onClick="window.location.href = window.location.protocol +'//'+ window.location.host + window.location.pathname;">
<?php else : ?>
<?php if (file_exists('/media/cdrom/dump.info')) : ?>
        <div class="alert alert-success" role="alert">
            <span class="glyphicon glyphicon-ok" aria-hidden="true"></span>
            <span class="sr-only">Success:</span>
            Valid SexiGraf export found: <strong><?php echo file_get_contents('/media/cdrom/dump.info', FILE_USE_INCLUDE_PATH); ?></strong>
        </div>
        <div class="alert alert-info" role="alert">
            <span class="glyphicon glyphicon-info-sign" aria-hidden="true"></span>
            <span class="sr-only">Info:</span>
            Beware that importing data from a upper or a very old version could cause some issues...<br>
            Current appliance version is: <strong><?php echo file_get_contents('/etc/sexigraf_version', FILE_USE_INCLUDE_PATH); ?></strong><br>
            Export version is: <strong><?php echo file_get_contents('/media/cdrom/sexigraf_version', FILE_USE_INCLUDE_PATH); ?></strong>            
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
<?php endif; ?>
    </div>
    <script type="text/javascript" src="js/bootstrap.min.js"></script>
</body>
</html>
