<?php 
session_start();
$title = "SexiGraf Package Update Runner";
$xmlPath = "/tmp/sexigraf-update/sexigraf-master/updateRunner.xml";
require("header.php");
require("helper.php");
$dir = '/var/www/admin/files/';
$SexiGrafVersion = (file_exists('/etc/sexigraf_version') ? file_get_contents('/etc/sexigraf_version', FILE_USE_INCLUDE_PATH) : "Unknown");
?>
    <div class="container"><br/>
	    <h2><span class="glyphicon glyphicon-hdd" aria-hidden="true"></span> SexiGraf Package Update Runner</h2>
<?php
	if ($_SERVER['REQUEST_METHOD'] == 'POST') {
		if ($_POST["submit"] != "upgrade-confirmed")
			echo '            <div class="alert alert-success" role="alert">
                <span class="glyphicon glyphicon-ok" aria-hidden="true"></span>
                <span class="sr-only">Success:</span>
                Current version of SexiGraf is: <strong>' . (file_exists('/etc/sexigraf_version') ? file_get_contents('/etc/sexigraf_version', FILE_USE_INCLUDE_PATH) : "Unknown") . '</strong>
            </div>
	    <div class="alert alert-warning" role="warning">
                <h4><span class="glyphicon glyphicon-alert" aria-hidden="true"></span>
                <span class="sr-only">Warning:</span>
                Upgrade process check!</h4>
		The upgrade process will be launched after you click on the \'Upgrade Me\' button.<br / >
		After the upgrade process is succeeded, SexiGraf services will be restarted.
		<p>The following file will be used for upgrade process: '.$_POST['input-file'].'</p>
		<form class="form" action="updateRunner.php" method="post">
			<input type="hidden" name="input-file" value="' . $_POST["input-file"] . '">
			<p><button name="submit" class="btn btn-info" value="upgrade-confirmed"><i class="glyphicon glyphicon-cog"></i> Upgrade Me</button>&nbsp;<a class="btn btn-danger" href="updater.php"><i class="glyphicon glyphicon-remove-sign"></i> Cancel</a></p>
        </div>';
                switch ($_POST["submit"]) {
                        case "upgrade-confirmed":
			echo "<pre>";
			unlinkRecursive("/tmp/sexigraf-update/");
			echo "Unpacking SexiGraf Update Package in /tmp/sexigraf-update/\n";
			echo shell_exec("/usr/bin/unzip \"".$dir.$_POST['input-file']."\" -d /tmp/sexigraf-update/ 2>&1");
			if (file_exists($xmlPath)) {
				$SexiGrafVersion = (file_exists('/etc/sexigraf_version') ? file_get_contents('/etc/sexigraf_version', FILE_USE_INCLUDE_PATH) : "Unknown");
				$domXML = new DomDocument();
				$domXML->load($xmlPath);
				$listeCommands = $domXML->getElementsByTagName('command');
				foreach($listeCommands as $command2Run){
                                        $command2sudo = $command2Run->firstChild->nodeValue;
                                        echo $command2sudo . "\n";
                                        echo shell_exec("sudo $command2sudo");
                                }

			} else {
				echo "!!! Missing mandatory file. Please check package integrity.\n";
			}
			echo "Purging temporary folder /tmp/sexigraf-update/";
			unlinkRecursive("/tmp/sexigraf-update/");
			echo "</pre>";
		}
	}
?>
	</div>
</body>
</html>
