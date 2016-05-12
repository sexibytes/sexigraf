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
		if ($_POST["submit"] != "upgrade-confirmed") {
      $tempVersionOutput = shell_exec("/usr/bin/unzip -p \"".$dir.$_POST['input-file']."\" sexigraf-master/updateRunner.xml");
      preg_match('/<version>(.*)<\/version>/', $tempVersionOutput, $matches);
			echo '            <div class="alert alert-success" role="alert" style="padding: 5px 15px;"><p><span class="glyphicon glyphicon-hdd" aria-hidden="true"></span> <span style="font-weight: normal;">Current installed version: </span><strong>' . $SexiGrafVersion . '</strong></p><p><span class="glyphicon glyphicon-floppy-disk" aria-hidden="true"></span> <span style="font-weight: normal;">New package version: </span><strong>' . $matches[0] . '</strong><p></div>
	    <div class="alert alert-warning" role="warning"><h4><span class="glyphicon glyphicon-alert" aria-hidden="true"></span><span class="sr-only">Warning:</span> Upgrade process check!</h4>The upgrade process will be launched after you click on the \'Upgrade Me\' button.<br / >After the upgrade process is succeeded, SexiGraf services will be restarted.<p>The following file will be used for upgrade process: '.$_POST['input-file'].'</p><form class="form" action="updateRunner.php" method="post"><input type="hidden" name="input-file" value="' . $_POST["input-file"] . '"><p><button name="submit" class="btn btn-info" value="upgrade-confirmed"><i class="glyphicon glyphicon-cog"></i> Upgrade Me</button>&nbsp;<a class="btn btn-danger" href="updater.php"><i class="glyphicon glyphicon-remove-sign"></i> Cancel</a></p></div>';
    } else {
			echo "<pre>";
			unlinkRecursive("/tmp/sexigraf-update/");
			$messageOutput = "Starting update process on " . (new DateTime())->format('Y-m-d H:i:s') . "\n";
			$tempMessageOutput = shell_exec("/usr/bin/unzip \"".$dir.$_POST['input-file']."\" -d /tmp/sexigraf-update/ 2>&1");
			if (file_exists($xmlPath)) {
				$domXML = new DomDocument();
				$domXML->load($xmlPath);
				$listeCommands = $domXML->getElementsByTagName('command');
				$SexiGrafNewVersion = $domXML->getElementsByTagName("version")->item(0)->nodeValue;
				$messageOutput .= "Updating from version " . trim($SexiGrafVersion) . " to version $SexiGrafNewVersion\n";
				$messageOutput .= "Unpacking SexiGraf Update Package in /tmp/sexigraf-update/\n";
				$messageOutput .= $tempMessageOutput;
				$errorInCommand = false;
				foreach($listeCommands as $command2Run){
					$outputCommand = [];
					$returnError = "";
          $command2sudo = $command2Run->firstChild->nodeValue;
          //exec("sudo $command2sudo", $outputCommand, $returnError);
					if ($returnError) {
						$messageOutput .= "[ERROR] Command run with errors: $command2sudo\n";
						$errorInCommand = true;
					} else {
						$messageOutput .= "[INFO] Command run successfully: $command2sudo\n";
					}
					$messageOutput .= implode("\n", $outputCommand) . "\n";
        }
			} else {
				$messageOutput .= "!!! Missing mandatory file. Please check package integrity.\n";
			}
			$messageOutput .= "Purging temporary folder /tmp/sexigraf-update/";
			unlinkRecursive("/tmp/sexigraf-update/");
			echo $messageOutput;
			echo "</pre>";
			$updateLog = fopen("update.log", "w");
			fwrite($updateLog, $messageOutput);
			fclose($updateLog);
			if ($errorInCommand) {
				echo ' <div class="alert alert-danger" role="danger"><h4><span class="glyphicon glyphicon-alert" aria-hidden="true"></span><span class="sr-only">Error:</span>There was some errors during the update process!</h4>Some errors occured during update of your SexiGraf appliance. This shouldn\'t happen, but don\'t worry, we are here to help you!<br />If you want, you can take a look above to the report that can point you to the right direction, or you can send it to us at plot &lt;at&gt; sexigraf.fr<p>You can fin update log <a href="update.log" target="_blank">here</a>, you can use the following button to send us an email with the details, we\'ll look into it and get back to you.</p><form class="form" action="" method="post"><p><a class="btn btn-danger" href="mailto:plot@sexigraf.fr?subject=Error during upgrade&body=Please Find attached update error log."><i class="glyphicon glyphicon-remove-sign"></i> Send Support Mail</a></p></div>';
			} else {
        echo ' <div class="alert alert-success" role="success"><h4><span class="glyphicon glyphicon-ok-sign" aria-hidden="true"></span><span class="sr-only">Success:</span>Update completed successfully!</h4><p>The update of your SexiGraf appliance completed successfully, you are now using version ' . $SexiGrafNewVersion . '!</p><p><a class="btn btn-success" href="index.php"><i class="glyphicon glyphicon-home"></i> Go Home</a></p></div>';
			}
		}
	}
?>
	</div>
</body>
</html>
