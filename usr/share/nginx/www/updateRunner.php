<?php 
session_start();
$title = "SexiGraf Package Update Runner";
require("header.php");
require("helper.php");
$dir = '/usr/share/nginx/www/files/';
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
			#$tmpFolder = trim(shell_exec('mktemp -d'));
			unlinkRecursive("/tmp/sexigraf-update/");
			echo "Unpacking SexiGraf Update Package in /tmp/sexigraf-update/\n";
			echo shell_exec("/usr/bin/unzip \"".$dir.$_POST['input-file']."\" -d /tmp/sexigraf-update/ 2>&1");
			if (file_exists("/tmp/sexigraf-update/sexigraf-master/updateRunner.sh")) {
				#echo "Updating Logstash configuration\n";
				#unlinkRecursive("/etc/logstash/conf.d/");
				#rcopy("$tmpFolder/logstash","/etc/logstash");
				#echo "Updating Riemann configuration\n";
				#unlinkRecursive("/etc/riemann/");
				#rcopy("$tmpFolder/riemann","/etc/riemann");
				#echo "Updating SexiGraf version\n";
				#copy("$tmpFolder/sexigraf_version","/etc/sexigraf_version");
				#echo "Updating SexiMenu configuration\n";
				#rcopy("$tmpFolder/seximenu","/root/seximenu");
				#echo "Press Enter to go on process and restart SexiGraf services...\n";
				#echo shell_exec("/etc/init.d/riemann stop");
				#echo shell_exec("/etc/init.d/logstash stop");
				#echo shell_exec("/etc/init.d/elasticsearch stop");
				#echo shell_exec("/etc/init.d/elasticsearch start");
				#echo shell_exec("/etc/init.d/riemann start");
				#echo shell_exec("/etc/init.d/logstash start");
				#echo shell_exec("/etc/init.d/node-app restart --force");
				#echo shell_exec("/etc/init.d/rsyslog restart");
				$SexiGrafVersion = (file_exists('/etc/sexigraf_version') ? file_get_contents('/etc/sexigraf_version', FILE_USE_INCLUDE_PATH) : "Unknown");
				#echo 'Current version of SexiGraf is: '.$SexiGrafVersion.'<br />';
				chmod("/tmp/sexigraf-update/sexigraf-master/updateRunner.sh", 0755);
				echo shell_exec("sudo /tmp/sexigraf-update/sexigraf-master/updateRunner.sh");
			} else {
				echo "!!! Missing mandatory file. Please check package integrity.\n";
			}
			echo "Purging temporary folder /tmp/sexigraf-update/";
			#unlinkRecursive("/tmp/sexigraf-update/");
			echo "</pre>";
		}
	}
?>
	</div>
</body>
</html>
