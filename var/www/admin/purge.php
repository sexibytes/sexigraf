<?php
session_start();
$title = "House Cleaner";
require("header.php");
require("helper.php");
?>
        <div class="container"><br/>
                <div class="panel panel-danger">
                        <div class="panel-heading"><h3 class="panel-title">House Cleaner Notes</h3></div>
                        <div class="panel-body"><ul>
                                <li>This page can be used to purge old and/or unwanted whisper data objects as well as vCenter session files.</li>
                                <li style="color:red;"><strong><span class="glyphicon glyphicon-alert" aria-hidden="true"></span> Beware as this operation cannot be undone, so there is a risk of DATA LOSS if you don't know what you're doing. <span class="glyphicon glyphicon-alert" aria-hidden="true"></span></strong></li>
                                <li>Autopurge will automatically remove all files that are not updated since selected days (default is 120).</li>
                                <li>Please refer to the <a href="http://www.sexigraf.fr/">project website</a> and documentation for more information.</li>
                        </ul></div>
                </div>
                <h2><span class="glyphicon glyphicon-trash" aria-hidden="true"></span> SexiGraf House Cleaner</h2>
                <div id="purgeLoading" style="display:block;">
                        <span class="glyphicon glyphicon-refresh glyphicon-refresh-animate"></span> Loading filesystem...
                </div>
<?php
        if ($_SERVER['REQUEST_METHOD'] == 'POST' and (!empty($_POST['file-to-delete']) or !empty($_POST['pathChecked']))) {
                switch ($_POST["submit"]) {
                        case "purge-files":
                                echo '  <div class="alert alert-warning" role="warning">
                <h4><span class="glyphicon glyphicon-alert" aria-hidden="true"></span>
                <span class="sr-only">Warning:</span>
                Confirmation needed!</h4>
                You are about to delete the following whisper data objects, are you sure about this? We mean, <strong>really sure</strong>?<br />
                <form class="form" action="purge.php" method="post">
                <ul>';
                                foreach($_POST['pathChecked'] as $check) {
                                        echo "<li><input type=\"hidden\" name=\"file-to-delete[]\" value=\"$check\">" . $check . "</li>\n";
                                }
                                echo '</ul>
                        <p><a class="btn btn-success" href="purge.php">Back</a> <button name="submit" class="btn btn-warning" value="purge-files-confirmed">Delete these objects</button></p>
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
                Object(s) successfully deleted.<br />
                <p><a class="btn btn-success" href="purge.php">Back</a></p>
                </div>';
                        break;
                }
        } else {
                if (!empty($_POST["submit"])) {
                        switch ($_POST["submit"]) {
                                case "enable-autopurge":
                                        enableAutopurge(intval($_POST["nb_days_purge"]));
                                break;
                                case "disable-autopurge":
                                        disableAutopurge();
                                break;
                        }
                }
                $topn = 50;
                echo '                <div id="purgeTree" style="display:none;">
                <form action="purge.php" method="post">
                <ul class="nav nav-tabs" role="tablist">
                        <li role="presentation" class="active"><a href="#whisper" aria-controls="whisper" role="tab" data-toggle="tab">Whisper repository</a></li>
                        <li role="presentation"><a href="#vcenter" aria-controls="vcenter" role="tab" data-toggle="tab">vCenter session files</a></li>
                        <li role="presentation"><a href="#oldies" aria-controls="oldies" role="tab" data-toggle="tab">Top ' . $topn . ' oldest whisper files</a></li>
                </ul>
                <div class="tab-content" style="padding-top: 10px;">
                        <div role="tabpanel" class="tab-pane fade in active" id="whisper">
                        ' . php_file_tree_dir("/var/lib/graphite/whisper") . '
                        </div>
                        <div role="tabpanel" class="tab-pane fade" id="vcenter">
                        ' . php_file_tree("/tmp", "dat") . '
                        </div>
                        <div role="tabpanel" class="tab-pane fade" id="oldies">
                        ' . php_file_tree_top_oldest("/var/lib/graphite/whisper", $topn) . '
                        </div>
                </div>
                <button name="submit" class="btn btn-danger" value="purge-files">Purge</button>
                </form>
                </div><br />
                <script type="text/javascript">
                        document.getElementById("purgeTree").style.display = "block";
                        document.getElementById("purgeLoading").style.display = "none";
                </script>';
        }
?>
                <div class="panel panel-warning">
                        <div class="panel-body">
                        <form action="purge.php" method="post">
                        Autopurge is currently
                        <?php
                        if (isAutopurgeEnabled()) {
                                $nbDaysPurge = file_get_contents('./graphite_autopurge');
                                echo '                        <span style="color:#5cb85c;" aria-hidden="true">enabled after ' . $nbDaysPurge . ' days</span>';
                                echo '                        &nbsp;<button name="submit" class="btn btn-default btn-danger" value="disable-autopurge">Disable autopurge</button>';
                        } else {
                                echo '                        <span style="color:#d9534f;" aria-hidden="true">disabled</span>';
                                echo '                        &nbsp;<button name="submit" class="btn btn-default btn-success" value="enable-autopurge">Enable autopurge</button> for <input type="number" id="nb_days_purge" name="nb_days_purge" min="1" value="120" style="width:80px;"> days';
                        }
                        ?>
                        </form>
                        </div>
                </div>
        </div>
        <script type="text/javascript" src="js/bootstrap.min.js"></script>
</body>
</html>
