<?php 
session_start();
$title = "SexiGraf vSphere Credential Store";
require("header.php");
require("helper.php");
?>
	<div class="container"><br/>
		<div class="panel panel-default">
			<div class="panel-heading"><h3 class="panel-title">Credential Store Notes</h3></div>
                	<div class="panel-body"><ul>
                        	<li>The credential store is used to store credential that will be used for vCenter query, it use vSphere SDK Credential Store Library</li>
                        	<li>Please refer to the <a href="http://www.sexigraf.fr/">project website</a> and <a href="http://www.sexigraf.fr/rtfm/">documentation</a> for more information.</li>
                    	</ul></div>
	        </div>
            	<h2><span class="glyphicon glyphicon-briefcase" aria-hidden="true"></span> SexiGraf Credential Store</h2>
		<table class="table table-hover">
      		<thead><tr>
	          <th class="col-sm-4">vCenter Name</th>
        	  <th class="col-sm-3">Username</th>
        	  <th class="col-sm-2">Password</th>
        	  <th class="col-sm-1">VI</th>
        	  <th class="col-sm-1">VSAN</th>
        	  <th class="col-sm-1">&nbsp;</th>
       		</tr></thead>
	      <tbody>
<?php 
	$credstoreData = shell_exec("/usr/lib/vmware-vcli/apps/general/credstore_admin.pl --credstore /var/www/.vmware/credstore/vicredentials.xml list");
	foreach(preg_split("/((\r?\n)|(\r\n?))/", $credstoreData) as $line) {
		if (strlen($line) == 0) { break; }
		if (preg_match('/^(?:(?!Server).)/', $line)) {
			$lineObjects = explode(" ", $line);
			echo '              <tr>
              		<td>' . $lineObjects[0] . "</td>
			<td>" . $lineObjects[1] . '</td>
			<td>***********</td>';
			if (isViEnabled($lineObjects[0])) {
                                echo '                        <td><span class="glyphicon glyphicon-ok-sign" style="color:#5cb85c;font-size:2em;" aria-hidden="true"></span></td>';
                        } else {
                                echo '                        <td><span class="glyphicon glyphicon-remove-sign" style="color:#d9534f;font-size:2em;" aria-hidden="true"></span></td>';
                        }
                        if (isVsanEnabled($lineObjects[0])) {
                                echo '                        <td><span class="glyphicon glyphicon-ok-sign" style="color:#5cb85c;font-size:2em;" aria-hidden="true"></span></td>';
                        } else {
                                echo '                        <td><span class="glyphicon glyphicon-remove-sign" style="color:#d9534f;font-size:2em;" aria-hidden="true"></span></td>';
                        }
			echo '			<td><form class="form" action="credstore.php" method="post">
				<input type="hidden" name="input-vcenter" value="' . $lineObjects[0] . '">
				<input type="hidden" name="input-username" value="' . $lineObjects[1] . '">
				<div class="btn-group">
					<button type="button" class="btn btn-primary dropdown-toggle" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
						Action <span class="caret"></span>
					</button>
					<ul class="dropdown-menu">';
			if (isViEnabled($lineObjects[0])) {
				echo '                          <li><button name="submit" class="btn btn-link btn-xs" value="disable-vi">Disable VI</button></li>';
			} else {
				echo '                          <li><button name="submit" class="btn btn-link btn-xs" value="enable-vi">Enable VI</button></li>';
			}
			if (isVsanEnabled($lineObjects[0])) {
				echo '                          <li><button name="submit" class="btn btn-link btn-xs" value="disable-vsan">Disable VSAN</button></li>';
			} else {
				echo '                          <li><button name="submit" class="btn btn-link btn-xs" value="enable-vsan">Enable VSAN</button></li>';
			}
			echo '				<li role="separator" class="divider"></li>
                          <li><button name="submit" class="btn btn-link btn-xs" value="delete-vcentry">Delete</button></li> 
                                        </ul>
				</div>
			</form></td>
		</tr>
';
		}
	} 
?>
		<tr><form class="form" action="credstore.php" method="post">
			<td><input type="text" class="form-control" name="input-vcenter" placeholder="vCenter IP or FQDN" aria-describedby="vcenter-label"></td>
			<td><input type="text" class="form-control" name="input-username" placeholder="Username" aria-describedby="username-label"></td>
			<td><input type="password" class="form-control" name="input-password" placeholder="Password" aria-describedby="password-label"></td>
			<td><button name="submit" class="btn btn-success" value="addmodify">Add</button></td>
		</form></tr>
	      </tbody>
	    </table>
<?php
	if ($_SERVER['REQUEST_METHOD'] == 'POST') {
		switch ($_POST["submit"]) {
			case "addmodify":
				$errorHappened = false;
				if (empty($_POST["input-vcenter"]) or empty($_POST["input-username"]) or empty($_POST["input-password"])) {
					$errorHappened = true;
					$errorMessage = "All mandatory values have not been provided."; 
				} elseif (!filter_var($_POST["input-vcenter"], FILTER_VALIDATE_IP) and (gethostbyname($_POST["input-vcenter"]) == $_POST["input-vcenter"])) {
		                        $errorHappened = true;
	        	                $errorMessage = "vCenter IP or FQDN is not correct.";
				} elseif (shell_exec("/usr/lib/vmware-vcli/apps/general/credstore_admin.pl --credstore /var/www/.vmware/credstore/vicredentials.xml list --server " . $_POST["input-vcenter"] . " | grep " . $_POST["input-vcenter"] . " | wc -l") > 0) {
                                	$errorHappened = true;
                                	$errorMessage = "vCenter IP or FQDN is already in credential store, duplicate entry is not supported.";
				} elseif (preg_match("/^([a-zA-Z0-9-_.]*)\\?([a-zA-Z0-9-_.]+)$|^([a-zA-Z0-9-_.]*)$|^([a-zA-Z0-9-_.]+)@([a-zA-Z0-9-_.]*)$/", $_POST["input-username"]) == 0) {
		                        $errorHappened = true;
	        	                $errorMessage = "Bad username format, supported format are DOMAIN\USERNAME, USERNAME, USERNAME@DOMAIN.TLD";
				}
				if ($errorHappened) {
					echo '	<div class="alert alert-danger" role="alert">
		<span class="glyphicon glyphicon-exclamation-sign" aria-hidden="true"></span>
		<span class="sr-only">Error:</span>
		' . $errorMessage . '
	</div>';
				} else {
					echo '	<div class="alert alert-success" role="alert">
		<span class="glyphicon glyphicon-ok" aria-hidden="true"></span>
		<span class="sr-only">Success:</span>';
					echo shell_exec("/usr/lib/vmware-vcli/apps/general/credstore_admin.pl --credstore /var/www/.vmware/credstore/vicredentials.xml add --server " . $_POST["input-vcenter"] . " --username " . $_POST["input-username"] . " --password " . $_POST["input-password"]);
					echo '	</div>';
					echo '<script type="text/javascript">setTimeout(function(){ location.replace("/credstore.php"); }, 1000);</script>';
				}
				break;
			case "delete-vcentry":
                                echo '  <div class="alert alert-warning" role="warning">
		<h4><span class="glyphicon glyphicon-alert" aria-hidden="true"></span>
                <span class="sr-only">Warning:</span>
		Confirmation needed!</h4>
		You are about to delete entry from VMware Credential Store for ' . $_POST["input-vcenter"] . '. Are you sure about this? We mean, <strong>really sure</strong>?<br />
		<form class="form" action="credstore.php" method="post">
                	<input type="hidden" name="input-vcenter" value="' . $_POST["input-vcenter"] . '">
                        <input type="hidden" name="input-username" value="' . $_POST["input-username"] . '">
			<p><button name="submit" class="btn btn-warning" value="delete-vcentry-confirmed">Delete entry</button></p>
		</form>';
                                echo '  </div>';
                                break;
			case "delete-vcentry-confirmed":
	                        echo '  <div class="alert alert-success" role="alert">
                <span class="glyphicon glyphicon-ok" aria-hidden="true"></span>
                <span class="sr-only">Success:</span>';
				echo shell_exec("/usr/lib/vmware-vcli/apps/general/credstore_admin.pl --credstore /var/www/.vmware/credstore/vicredentials.xml remove --server " . $_POST["input-vcenter"] . " --username " . $_POST["input-username"]) . "Refreshing...";
				echo '  </div>';
				echo '<script type="text/javascript">setTimeout(function(){ location.replace("/credstore.php"); }, 1000);</script>';
				break;
			case "enable-vi":
				enableVi($_POST["input-vcenter"]);
			        echo '  <div class="alert alert-success" role="alert">
                <span class="glyphicon glyphicon-ok" aria-hidden="true"></span>
                <span class="sr-only">Success:</span>
		VI query successfully enabled for ' . $_POST["input-vcenter"] . ', refreshing...
	</div>
	<script type="text/javascript">setTimeout(function(){ location.replace("/credstore.php"); }, 1000);</script>';
				break;
			case "enable-vsan":
				enableVsan($_POST["input-vcenter"]);
                                echo '  <div class="alert alert-success" role="alert">
                <span class="glyphicon glyphicon-ok" aria-hidden="true"></span>
                <span class="sr-only">Success:</span>
                VSAN query successfully enabled for ' . $_POST["input-vcenter"] . ', refreshing...
        </div>
        <script type="text/javascript">setTimeout(function(){ location.replace("/credstore.php"); }, 1000);</script>';
				break;
			case "disable-vi":
				disableVi($_POST["input-vcenter"]);
				echo '  <div class="alert alert-success" role="alert">
                <span class="glyphicon glyphicon-ok" aria-hidden="true"></span>
                <span class="sr-only">Success:</span>
                VI query successfully disabled for ' . $_POST["input-vcenter"] . ', refreshing...
        </div>
        <script type="text/javascript">setTimeout(function(){ location.replace("/credstore.php"); }, 1000);</script>';
				break;
			case "disable-vsan":
				disableVsan($_POST["input-vcenter"]);
                                echo '  <div class="alert alert-success" role="alert">
                <span class="glyphicon glyphicon-ok" aria-hidden="true"></span>
                <span class="sr-only">Success:</span>
                VSAN query successfully disabled for ' . $_POST["input-vcenter"] . ', refreshing...
        </div>
        <script type="text/javascript">setTimeout(function(){ location.replace("/credstore.php"); }, 1000);</script>';
				break;
		}
	}
?>
	</div>
</body>
</html>
