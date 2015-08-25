<?php 
session_start();
$title = "SexiGraf vSphere Credential Store";
require("header.php");
require("helper.php");
?>
	<div class="container"><br/>
		<div class="panel panel-danger">
			<div class="panel-heading"><h3 class="panel-title">Whisper Purge Notes</h3></div>
                	<div class="panel-body"><ul>
                        	<li>This page can be used to purge old and/or bad whisper data files.</li>
				<li style="color:red;"><strong><span class="glyphicon glyphicon-alert" aria-hidden="true"></span> Beware as this operation cannot be undone, so there is a risk of DATA LOSS if you don't know what you're doing. <span class="glyphicon glyphicon-alert" aria-hidden="true"></span></strong></li>
                        	<li>Please refer to the <a href="http://www.sexigraf.fr/">project website</a> and <a href="http://www.sexigraf.fr/rtfm/">documentation</a> for more information.</li>
                    	</ul></div>
	        </div>
            	<h2><span class="glyphicon glyphicon-trash" aria-hidden="true"></span> SexiGraf Whisper Purge</h2>
		<div id="purgeLoading" style="display:block;">
			<span class="glyphicon glyphicon-refresh glyphicon-refresh-animate"></span> Loading filesystem...
		</div>
<?php
	if ($_SERVER['REQUEST_METHOD'] == 'POST') {
		switch ($_POST["submit"]) {
			case "purge-files":
				echo '  <div class="alert alert-warning" role="warning">
                <h4><span class="glyphicon glyphicon-alert" aria-hidden="true"></span>
                <span class="sr-only">Warning:</span>
                Confirmation needed!</h4>
                You are about to delete the following whisper data files, are you sure about this? We mean, <strong>really sure</strong>?<br />
	        <form class="form" action="purge.php" method="post">
		<ul>';
		foreach($_POST['pathChecked'] as $check) { 
			echo "<li><input type=\"hidden\" name=\"file-to-delete[]\" value=\"$check\">" . $check . "</li>\n"; 
		}
				echo '</ul>
                        <p><a class="btn btn-success" href="purge.php">Back</a> <button name="submit" class="btn btn-warning" value="purge-files-confirmed">Delete these files</button></p>
                </form>';
				echo '<script type="text/javascript">
                		        document.getElementById("purgeLoading").style.display = "none";
                		</script>';
			break;
			case "purge-files-confirmed":
				echo '<script type="text/javascript">
                                        document.getElementById("purgeLoading").style.display = "none";
                                </script>';
				foreach($_POST['file-to-delete'] as $file2delete) {
					shell_exec("sudo /bin/bash /var/www/scripts/purgeWhisperFile.sh $file2delete");
		                }
				echo '  <div class="alert alert-success" role="success">
                <span class="glyphicon glyphicon-ok" aria-hidden="true"></span>
                <span class="sr-only">Success:</span>
                File(s) successfully deleted.<br />
		<p><a class="btn btn-success" href="purge.php">Back</a></p>
		</div>';
			break;
		}
	} else {
		echo '                <div id="purgeTree" style="display:none;">
		<form action="purge.php" method="post">';
		echo php_file_tree_dir("/var/lib/graphite/whisper"); 
		echo '		<button name="submit" class="btn btn-danger" value="purge-files">Purge</button>
		</form>
		</div>
		<script type="text/javascript">
			document.getElementById("purgeTree").style.display = "block";
			document.getElementById("purgeLoading").style.display = "none";
		</script>';
	}
?>
	</div>
</body>
</html>
