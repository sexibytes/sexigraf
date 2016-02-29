<?php
session_start();
$title = "SexiGraf Package Updater";
require("header.php");
require("helper.php");
$dir = "/var/www/admin/files/";
?>
    <div class="container"><br/>
            <div class="panel panel-default">
                <div class="panel-heading"><h3 class="panel-title">Update Package Notes</h3></div>
                <div class="panel-body">
                    <ul>
                        <li>The maximum file size for uploads in this package updater <strong>500 KB</strong></li>
                        <li>Use this page to upload SexiGraf Update Package files (<strong>SUP</strong>)</li>
                        <li>Please refer to the <a href="http://www.sexigraf.fr/">project website</a> and documentation for more information.</li>
                    </ul>
                </div>
            </div>
            <h2><span class="glyphicon glyphicon-hdd" aria-hidden="true"></span> SexiGraf Package Updater</h2>
            <div class="alert alert-success" role="alert">
                <span class="glyphicon glyphicon-ok" aria-hidden="true"></span>
                <span class="sr-only">Success:</span>
                Current version of SexiGraf is: <strong><?php echo (file_exists('/etc/sexigraf_version') ? file_get_contents('/etc/sexigraf_version', FILE_USE_INCLUDE_PATH) : "Unknown"); ?></strong>
            </div>
            <form action="updater.php" method="post" enctype="multipart/form-data">
                    <input type="hidden" name="MAX_FILE_SIZE" value="500000"/>
                    <div class="alert alert-warning" role="warning">
            			<div class="row">
            				<div class="col-sm-2" style="margin-top: 7px;"><h4 id="uploadCase"><span class="glyphicon glyphicon-file" aria-hidden="true"></span><span class="sr-only">Warning:</span> Select file to upload</h4></div>
            				<div class="col-sm-8">
                              <div class="input-group">
                                <span class="input-group-btn">
                                  <span class="btn btn-warning btn-file">Browse&hellip; <input type="file" name="fileToUpload" id="fileToUpload"></span>
                                </span>
                                <input type="text" class="form-control" readonly>
                              </div>
                            </div>
            				<div class="col-sm-2 text-right"><button name="submit" class="btn btn-warning" value="uploading" style="width:196px"><i class="glyphicon glyphicon-upload"></i> Upload Package</button></div>
            			</div>
            		</div>
            </form>
<?php
        if ($handle = opendir($dir)) {
                echo '          <table role="presentation" class="table table-striped"><tbody class="files">';
                while (false !== ($file = readdir($handle))) {
                        if ($file != "." && $file != ".." && $file != ".gitignore") {
                                echo '          <tr class="template-download fade in">';
                                echo '        <td><span class="preview"></span></td>';
                                echo '        <td><p class="name">'.$file.'</p></td>';
                                echo '        <td><p class="size">'.humanFileSize(filesize($dir.$file),"KB").'</p></td>';
                                echo '        <td style="width:220px"><form class="form" style="display:inline;" action="updater.php" method="post">';
                                echo '            <input type="hidden" name="input-file" value="' . $file . '">';
                                echo '            <button name="submit" class="btn btn-danger delete" style="width:95px" value="delete-file"><i class="glyphicon glyphicon-trash"></i> Delete</button></form>';
                                echo '            <form class="form" style="display:inline;" action="updateRunner.php" method="post"><input type="hidden" name="input-file" value="' . $file . '"><button name="submit" class="btn btn-primary" style="width:95px" value="update-sexigraf"><i class="glyphicon glyphicon-cog"></i> Upgrade</button>';
                                echo '        </form></td></tr>';
                    }
                }
                closedir($handle);
                echo '          </tbody></table>';
        }
        if ($_SERVER['REQUEST_METHOD'] == 'POST') {
                switch ($_POST["submit"]) {
                        case "uploading":
                                $errorUploadHappened = false;
                                if ($_FILES['fileToUpload']['error'] > 0) {
                                        $errorUploadHappened = true;
                                        switch ($_FILES['fileToUpload']['error']) {
                                                case 1:
                                                        $errorUploadMessage = 'File exceeded upload_max_filesize';
                                                break;
                                                case 2:
                                                        $errorUploadMessage = 'File exceeded max_file_size';
                                                break;
                                                case 3:
                                                        $errorUploadMessage = 'File only partially uploaded';
                                                break;
                                                case 4:
                                                        $errorUploadMessage = 'No file uploaded';
                                                break;
                                                case 6:
                                                        $errorUploadMessage = 'Cannot upload file: No temp directory specified.';
                                                break;
                                                case 7:
                                                        $errorUploadMessage = 'Upload failed: Cannot write to disk.';
                                                break;
                                        }
                                } elseif (pathinfo($_FILES['fileToUpload']['name'])['extension'] == "sup") {
                                        $upfile = 'files/'.$_FILES['fileToUpload']['name'];
                                        if (is_uploaded_file($_FILES['fileToUpload']['tmp_name'])) {
                                                if (!move_uploaded_file($_FILES['fileToUpload']['tmp_name'], $upfile)) {
                                                        $errorUploadHappened = true;
                                                        $errorUploadMessage = 'Could not move file to destination directory';
                                                } else {
                                                        echo '  <div class="alert alert-success" role="alert">
                <span class="glyphicon glyphicon-ok" aria-hidden="true"></span>
                <span class="sr-only">Success:</span>
                File ' . $_FILES['fileToUpload']['name'] . ' successfully uploaded. Refreshing...';
                                                        echo '  </div>';
                                                        echo '<script type="text/javascript">setTimeout(function(){ location.replace("updater.php"); }, 1000);</script>';
                                                }
                                        }
                                } else {
                                        $errorUploadHappened = true;
                                        $errorUploadMessage = 'Wrong filetype. Only official SexiGraf .sup package is allowed';
                                }
                        break;
                        case "delete-file":
                                echo '  <div class="alert alert-warning" role="warning">
                <h4><span class="glyphicon glyphicon-alert" aria-hidden="true"></span>
                <span class="sr-only">Warning:</span>
                Confirmation needed!</h4>
                You are about to delete SexiGraf Update Package ' . $_POST["input-file"] . '. Are you sure about this? We mean, <strong>really sure</strong>?<br />
                <form class="form" action="updater.php" method="post">
                        <input type="hidden" name="input-file" value="' . $_POST["input-file"] . '">
                        <p><button name="submit" class="btn btn-warning" value="delete-file-confirmed">Delete file</button></p>
                </form>';
                        break;
                        case "delete-file-confirmed":
                                unlink($dir.$_POST["input-file"]);
                                echo '  <div class="alert alert-success" role="alert">
                <span class="glyphicon glyphicon-ok" aria-hidden="true"></span>
                <span class="sr-only">Success:</span>
                File ' . $_POST["input-file"] . ' successfully deleted. Refreshing...';
                                echo '  </div>';
                                echo '<script type="text/javascript">setTimeout(function(){ location.replace("updater.php"); }, 1000);</script>';
                        break;
                }
                if (isset($errorUploadHappened) and ($errorUploadHappened)) {
                        echo '  <div class="alert alert-danger" role="alert">
                <span class="glyphicon glyphicon-exclamation-sign" aria-hidden="true"></span>
                <span class="sr-only">Error:</span>
                Error during upload: ' . $errorUploadMessage . '
        </div>';
                }
        }
?>
        </div>
        <script type="text/javascript" src="js/bootstrap.min.js"></script>
</body>
</html>
