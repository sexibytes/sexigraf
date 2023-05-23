<?php
session_start();
$title = "SexiGraf Veeam Credential Store";
require("header.php");
require("helper.php");
?>
        <div class="container"><br/>
                <div class="panel panel-default">
                        <div class="panel-heading"><h3 class="panel-title">Veeam Credential Store Notes</h3></div>
                        <div class="panel-body"><ul>
                                <li>The Veeam credential store is used to store credential that will be used for Veeam Backup Server query, it uses the RESTful API for VBR (v11+)</li>
                                <li><font style="color:red;"><i class="glyphicon glyphicon-alert"></i></font> Removing a VBR Server from the credential store will <b><font style="color:red;">NOT delete any collected metrics</font></b>.</li>
                                <li>Please refer to the <a href="http://www.sexigraf.fr/">project website</a> and documentation for more information.</li>
                        </ul></div>
                </div>
                <h2><span class="glyphicon glyphicon-briefcase" aria-hidden="true"></span> SexiGraf Veeam Credential Store</h2>
                <table class="table table-hover">
                <thead><tr>
                        <th class="col-sm-4">VBR Server address</th>
                        <th class="col-sm-3">Username</th>
                        <th class="col-sm-2">Password</th>
                        <th class="col-sm-1">Enabled</th>
                        <th class="col-sm-1">&nbsp;</th>
                </tr></thead>
        <tbody>
<?php
        $credstoreData = shell_exec("/usr/bin/pwsh -NonInteractive -NoProfile -f /opt/sexigraf/CredstoreAdmin.ps1 -credstore /mnt/wfs/inventory/vbrpscredentials.xml -list");
        foreach(preg_split("/((\r?\n)|(\r\n?))/", $credstoreData) as $line) {
                if (strlen($line) == 0) { continue; }
                // if (preg_match('/^(?:(?!Server).)/', $line)) {
                if (preg_match('/^(?:(?!__localhost__).)/', $line)) {
                        $lineObjects = preg_split('/\s+/', $line);
                        echo '              <tr>
                        <td>' . $lineObjects[0] . "</td>
                        <td>" . $lineObjects[1] . '</td>
                        <td>***********</td>';
                        if (isVbrEnabled($lineObjects[0])) {
                                echo '                        <td><span class="glyphicon glyphicon-ok-sign" style="color:#5cb85c;font-size:2em;" aria-hidden="true"></span></td>';
                        } else {
                                echo '                        <td><span class="glyphicon glyphicon-remove-sign" style="color:#d9534f;font-size:2em;" aria-hidden="true"></span></td>';
                        }
                        echo '                  <td><form class="form" action="vbrcredstore.php" method="post">
                                <input type="hidden" name="input-vbr" value="' . $lineObjects[0] . '">
                                <input type="hidden" name="input-username" value="' . $lineObjects[1] . '">
                                <div class="btn-group">
                                        <button type="button" class="btn btn-primary dropdown-toggle" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
                                                Action <span class="caret"></span>
                                        </button>
                                        <ul class="dropdown-menu">';
                        if (isVbrEnabled($lineObjects[0])) {
                                echo '                          <li><button name="submit" class="btn btn-link btn-xs" value="disable-vbr">Disable VBR</button></li>';
                        } else {
                                echo '                          <li><button name="submit" class="btn btn-link btn-xs" value="enable-vbr">Enable VBR</button></li>';
                        }
                        echo '                          <li role="separator" class="divider"></li>
                                <li><button name="submit" class="btn btn-link btn-xs" value="delete-vcentry">Delete</button></li>
                                        </ul>
                                </div>
                        </form></td>
                </tr>
';
                }
        }
?>
                <tr><form class="form" action="vbrcredstore.php" method="post">
                        <td><input type="text" class="form-control" name="input-vbr" placeholder="VBR IP or FQDN" aria-describedby="vcenter-label"></td>
                        <td><input type="text" class="form-control" name="input-username" placeholder="Username" aria-describedby="username-label"></td>
                        <td><input type="password" class="form-control" name="input-password" placeholder="Password" aria-describedby="password-label"></td>
                        <td>&nbsp;*</td>
                        <td><button name="submit" class="btn btn-success" value="addmodify" onclick="document.getElementById('submitmessage').style.display = 'block'">Add</button></td>
                </form></tr>
                </tbody>
                </table>
                <div id="submitmessage" class="alert alert-warning" role="warning" style="display: none">
                <span class="glyphicon glyphicon-exclamation-sign" aria-hidden="true"></span>
                <span class="sr-only">Warning:</span>Please wait while we validate server reachability and user access...
                </div>
<?php
        if ($_SERVER['REQUEST_METHOD'] == 'POST') {
                switch ($_POST["submit"]) {
                        case "addmodify":
                                $errorHappened = false;
                                if (empty($_POST["input-vbr"]) or empty($_POST["input-username"]) or empty($_POST["input-password"])) {
                                        $errorHappened = true;
                                        $errorMessage = "All mandatory values have not been provided.";
                                } elseif (!filter_var($_POST["input-vbr"], FILTER_VALIDATE_IP) and (gethostbyname($_POST["input-vbr"]) == $_POST["input-vbr"])) {
                                        $errorHappened = true;
                                        $errorMessage = "VBR IP or FQDN is not correct.";
                                } elseif (shell_exec("/usr/bin/pwsh -NonInteractive -NoProfile -f /opt/sexigraf/CredstoreAdmin.ps1 -credstore /mnt/wfs/inventory/vbrpscredentials.xml -check -server " . $_POST["input-vbr"]) > 0) {
                                        $errorHappened = true;
                                        $errorMessage = "VBR IP or FQDN is already in credential store, duplicate entry is not supported.";
                                } elseif (preg_match("/^([a-zA-Z0-9-_.]*)\\\\?([a-zA-Z0-9-_.]+)$|^([a-zA-Z0-9-_.]*)$|^([a-zA-Z0-9-_.]+)@([a-zA-Z0-9-_.]*)$/", $_POST["input-username"]) == 0) {
                                        $errorHappened = true;
                                        $errorMessage = "Wrong username format, supported format are DOMAIN\USERNAME, USERNAME, USERNAME@DOMAIN.TLD";
                                } else {
                                        exec("/usr/bin/pwsh -NonInteractive -NoProfile -f /opt/veeam/VbrConnect.ps1 -server " . escapeshellcmd($_POST["input-vbr"]) . " -username " . escapeshellcmd($_POST["input-username"]) . " -password " . escapeshellcmd($_POST["input-password"]), $null, $return_var);
                                        if ($return_var) {
                                                $errorHappened = true;
                                                $errorMessage = "Wrong username/password or no answer at TCP:9419";
                                        }
                                }

                                if ($errorHappened) {
                                        echo '  <div class="alert alert-danger" role="alert">
                                        <span class="glyphicon glyphicon-exclamation-sign" aria-hidden="true"></span>
                                        <span class="sr-only">Error:</span>
                                        ' . $errorMessage . '
                                        </div>';
                                        echo '<script type="text/javascript">setTimeout(function(){ location.replace("vbrcredstore.php"); }, 2000);</script>';
                                } else {
                                        echo '  <div class="alert alert-success" role="alert">
                                        <span class="glyphicon glyphicon-ok" aria-hidden="true"></span>
                                        <span class="sr-only">Success:</span> Success!';
                                        echo exec("/usr/bin/pwsh -NonInteractive -NoProfile -f /opt/sexigraf/CredstoreAdmin.ps1 -credstore /mnt/wfs/inventory/vbrpscredentials.xml -add -server " . escapeshellcmd($_POST["input-vbr"]) . " -username " . escapeshellcmd($_POST["input-username"]) . " -password " . escapeshellcmd($_POST["input-password"]));
                                        // Once newly VBR has been added, we want the inventory to be updated
                                        // shell_exec("sudo /bin/bash /var/www/scripts/updateInventory.sh > /dev/null 2>/dev/null &");
                                        echo '  </div>';
                                        echo '<script type="text/javascript">setTimeout(function(){ location.replace("vbrcredstore.php"); }, 2000);</script>';
                                }
                                break;
                        case "delete-vcentry":
                                echo '  <div class="alert alert-warning" role="warning">
                <h4><span class="glyphicon glyphicon-alert" aria-hidden="true"></span>
                <span class="sr-only">Warning:</span>
                Confirmation needed!</h4>
                You are about to delete entry from Veeam Credential Store for ' . $_POST["input-vbr"] . '. Are you sure about this? We mean, <strong>really sure</strong>?<br />
                <form class="form" action="vbrcredstore.php" method="post">
                        <input type="hidden" name="input-vbr" value="' . $_POST["input-vbr"] . '">
                        <input type="hidden" name="input-username" value="' . $_POST["input-username"] . '">
                        <p><button name="submit" class="btn btn-warning" value="delete-vcentry-confirmed">Delete entry</button></p>
                </form>';
                                echo '  </div>';
                                break;
                        case "delete-vcentry-confirmed":
                                disableVbr($_POST["input-vbr"]);
                                echo '  <div class="alert alert-success" role="alert">
                <span class="glyphicon glyphicon-ok" aria-hidden="true"></span>
                <span class="sr-only">Success:</span>';
                                echo exec("/usr/bin/pwsh -NonInteractive -NoProfile -f /opt/sexigraf/CredstoreAdmin.ps1 -credstore /mnt/wfs/inventory/vbrpscredentials.xml -remove -server " . escapeshellcmd($_POST["input-vbr"])) . "Refreshing...";
                                // shell_exec("sudo /bin/bash /var/www/scripts/updateInventory.sh > /dev/null 2>/dev/null &");
                                echo '  </div>';
                                echo '<script type="text/javascript">setTimeout(function(){ location.replace("vbrcredstore.php"); }, 1000);</script>';
                                break;
                        case "enable-vbr":
                                enableVbr($_POST["input-vbr"]);
                                echo '  <div class="alert alert-success" role="alert">
                <span class="glyphicon glyphicon-ok" aria-hidden="true"></span>
                <span class="sr-only">Success:</span>
                VBR query successfully enabled for ' . $_POST["input-vbr"] . ', refreshing...
        </div>
        <script type="text/javascript">setTimeout(function(){ location.replace("vbrcredstore.php"); }, 1000);</script>';
                                break;
                        case "disable-vbr":
                                disableVbr($_POST["input-vbr"]);
                                echo '  <div class="alert alert-success" role="alert">
                <span class="glyphicon glyphicon-ok" aria-hidden="true"></span>
                <span class="sr-only">Success:</span>
                VBR query successfully disabled for ' . $_POST["input-vbr"] . ', refreshing...
        </div>
        <script type="text/javascript">setTimeout(function(){ location.replace("vbrcredstore.php"); }, 1000);</script>';
                                break;
                }
        }
?>
        </div>
        <script type="text/javascript" src="js/bootstrap.min.js"></script>
</body>
</html>
