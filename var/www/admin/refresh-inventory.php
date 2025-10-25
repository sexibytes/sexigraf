<?php
session_start();
$title = "SexiGraf Inventory Refresh & History";
require("header.php");
require("helper.php");
?>
        <div class="container"><br/>
                <div class="panel panel-default">
                        <div class="panel-heading"><h3 class="panel-title">Refresh VI Offline Inventory Notes</h3></div>
                        <div class="panel-body"><ul>
                                <li>The Static VI Offline Inventory is automatically updated every hour.</li>
                                <li>If you want to force a refresh, you can use this section to perform update</li>
                        </ul></div>
                </div>
                <h2><span class="glyphicon glyphicon-refresh" aria-hidden="true"></span> Refresh SexiGraf VI Offline Inventory</h2>
                <div class="alert alert-success" role="success">
                        <span class="glyphicon glyphicon-info-sign" aria-hidden="true"></span>
                        Last VI Offline Inventory generated on (UTC):
<?php
        $inventoryPath = "/mnt/wfs/inventory/ViVmInventory.csv";
        if (file_exists($inventoryPath)) {
                echo date("F d Y H:i:s.", filemtime($inventoryPath));
        } else {
                echo "[ERROR] File $inventoryPath doesn't exist, thus no inventory is present.";
        }
?>
<?php
        if ($_SERVER['REQUEST_METHOD'] == 'POST') {
                switch ($_POST["submit"]) {
                        case "refresh-inventory":
                                echo '  </div><div class="alert alert-warning" role="warning">
                <h4><span class="glyphicon glyphicon-alert" aria-hidden="true"></span>
                <span class="sr-only">Warning:</span>
                Confirmation needed!</h4>
                You are about to force VI inventory update. It should be use only for DEBUG purpose as it is already scheduled to run hourly.<br />The process itself can take a few seconds (or minutes depending on your platform size). Are you sure about this? We mean, <strong>really sure</strong>?<br />
                <form class="form" action="refresh-inventory.php" method="post">
                        <p><button name="submit" class="btn btn-warning" value="refresh-inventory-confirmed">Confirm inventory refresh</button></p>
                </form>';
                                echo '  </div>';
                                break;

                        case "refresh-inventory-confirmed":
                                echo '  </div><div class="alert alert-success" role="alert">
                <span class="glyphicon glyphicon-ok" aria-hidden="true"></span>
                <span class="sr-only">Success:</span>';
                                echo shell_exec("nohup sudo /bin/bash /var/www/scripts/updateInventory.sh");
                                echo '          Vi Offline Inventory update launched successfully!
        </div>';
                                echo '<script type="text/javascript">setTimeout(function(){ location.replace("refresh-inventory.php"); }, 1000);</script>';
                                break;

                        case "set-InvWeeks":
                                echo '  </div>';
                                if (isset($_POST["NewInvWeeks"]) && is_numeric($_POST["NewInvWeeks"]) && intval($_POST["NewInvWeeks"]) > 0) {
                                        setInvWeeks(intval($_POST["NewInvWeeks"]));
                                        echo '<div class="alert alert-success" role="alert">
                                                <span class="glyphicon glyphicon-ok" aria-hidden="true"></span>
                                                <span class="sr-only">Success:</span>
                                                Inventory retention updated to ' . intval($_POST["NewInvWeeks"]) . ' weeks.
                                              </div>';
                                        echo '<script type="text/javascript">setTimeout(function(){ location.replace("refresh-inventory.php"); }, 800);</script>';
                                } else {
                                        echo '<div class="alert alert-danger" role="alert">
                                                <span class="glyphicon glyphicon-remove" aria-hidden="true"></span>
                                                <span class="sr-only">Error:</span>
                                                Please provide a valid number of weeks (>= 1).
                                              </div>';
                                }
                                break;
                }
        } else {
                echo '                        <form class="form" action="refresh-inventory.php" method="post">
                                <p><button name="submit" class="btn btn-success" value="refresh-inventory">Force VI Inventory Refresh</button></p>
                        </form>
                </div>';
        }
?>

<?php
        $dir = "/mnt/wfs/inventory/";
        chdir($dir);
        $invlist = ""; // prevent undefined variable notice
        array_multisort(array_map('filemtime', ($files = glob("*.20*.csv"))), SORT_DESC, $files);
        foreach($files as $filename) {
                if ($filename != "." && $filename != ".." && $filename != "vipscredentials.xml" && $filename != "vbrpscredentials.xml") {
                        $invlist .= '<li><a href="/sexihistory/'.$filename.'">'.$filename.'</a></li>';
                }
        }
?>
<div class="panel panel-warning">
        <div class="panel-body">
        VI Offline Inventory retention is currently
        <?php
                $InvWeeksValue = getInvWeeks();
                echo '                        <span style="color:#5cb85c;" aria-hidden="true">' . $InvWeeksValue . ' weeks</span>';

                echo '                        <form class="form" action="refresh-inventory.php" method="post" style="display:inline;margin-left:8px;">
                                                <button name="submit" class="btn btn-default btn-success" value="set-InvWeeks">Change Retention</button>
                                                to
                                                <input type="number" id="NewInvWeeks" name="NewInvWeeks" min="1" value="' . htmlspecialchars($InvWeeksValue) . '" style="width:80px;"> weeks
                                       </form>';
        ?>
        </div>
</div>
<h1>Inventory History:</h1>
<ul><?php echo $invlist; ?></ul>

        <script type="text/javascript" src="js/bootstrap.min.js"></script>
</body>
</html>