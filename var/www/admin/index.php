<?php
session_start();
$title = "SexiGraf summary";
require("header.php");
?>
        <div class="row" style="margin:0px;padding:30px 30px 0px 30px;">
                <div class="col-lg-4 col-md-6">
                        <a href="credstore.php">
                                <div class="panel panel-primary">
                                        <div class="panel-heading">
                                                <div class="row">
                                                        <div class="col-xs-2">
                                                                <i class="glyphicon glyphicon-briefcase" style="font-size: 2em;"></i>
                                                        </div>
                                                        <div class="col-xs-10 text-right">
                                                                <div class="huge">vSphere Credential Store</div>
                                                        </div>
                                                </div>
                                        </div>
                                        <div class="panel-footer">
                                                <span class="pull-left">In this section, you'll be able to manage your VMware Credential Store. This store is used to set up your vCenter/ESX information to allow SexiGraf query what's needed.</span>
                                                <div class="clearfix"></div>
                                        </div>
                                </div>
                        </a>
                </div>
                <div class="col-lg-4 col-md-6">
                        <a href="updater.php">
                                <div class="panel panel-green">
                                        <div class="panel-heading">
                                                <div class="row">
                                                        <div class="col-xs-2">
                                                                <i class="glyphicon glyphicon-hdd" style="font-size: 2em;"></i>
                                                        </div>
                                                        <div class="col-xs-10 text-right">
                                                                <div class="huge">Package Updater</div>
                                                        </div>
                                                </div>
                                        </div>
                                        <div class="panel-footer">
                                                <span class="pull-left">Here you'll find the update process of SexiGraf. Once you have downloaded an update package, go on this section to give your appliance the State-Of-The-Art code!</span>
                                                <div class="clearfix"></div>
                                        </div>
                                </div>
                        </a>
                </div>
                <div class="col-lg-4 col-md-6">
                        <a href="purge.php">
                                <div class="panel panel-red">
                                        <div class="panel-heading">
                                                <div class="row">
                                                        <div class="col-xs-2">
                                                                <i class="glyphicon glyphicon-trash" style="font-size: 2em;"></i>
                                                        </div>
                                                        <div class="col-xs-10 text-right">
                                                                <div class="huge">House Cleaner</div>
                                                        </div>
                                                </div>
                                        </div>
                                        <div class="panel-footer">
                                                <span class="pull-left">The House Cleaner page will let you manage Graphite data (Whisper files). It can be useful to remove from web-ui the legacy or orphaned stats (i.e. after datastore removal).</span>
                                                <div class="clearfix"></div>
                                        </div>
                                </div>
                        </a>
                </div>
        </div>
        <div class="row" style="margin:0px;padding:30px 30px 0px 30px;">
                <div class="col-lg-4 col-md-6">
                        <a href="refresh-inventory.php">
                                <div class="panel panel-yellow">
                                        <div class="panel-heading">
                                                <div class="row">
                                                        <div class="col-xs-2">
                                                                <i class="glyphicon glyphicon-th-list" style="font-size: 2em;"></i>
                                                        </div>
                                                        <div class="col-xs-10 text-right">
                                                                <div class="huge">Refresh Inventories</div>
                                                        </div>
                                                </div>
                                        </div>
                                        <div class="panel-footer">
                                                <span class="pull-left">The VMware and Veeam inventories are automatically updated every hours. If you need to force a refresh sooner, you can use this section to force the update.</span>
                                                <div class="clearfix"></div>
                                        </div>
                                </div>
                        </a>
                </div>
                <div class="col-lg-4 col-md-6">
                        <a href="showlog.php">
                                <div class="panel panel-grey">
                                        <div class="panel-heading">
                                                <div class="row">
                                                        <div class="col-xs-2">
                                                                <i class="glyphicon glyphicon-search" style="font-size: 2em;"></i>
                                                        </div>
                                                        <div class="col-xs-10 text-right">
                                                                <div class="huge">Log Viewer</div>
                                                        </div>
                                                </div>
                                        </div>
                                        <div class="panel-footer">
                                                <span class="pull-left">The Log Viewer will give you access to the content of SexiGraf log files. It is basically a web equivalent of the <code>tail -f</code> linux command. It should be used for debug purpose</span>
                                                <div class="clearfix"></div>
                                        </div>
                                </div>
                        </a>
                </div>
                <div class="col-lg-4 col-md-6">
                        <a href="export-import.php">
                                <div class="panel">
                                        <div class="panel-heading">
                                                <div class="row">
                                                        <div class="col-xs-2">
                                                                <i class="glyphicon glyphicon-transfer" style="font-size: 2em;"></i>
                                                        </div>
                                                        <div class="col-xs-10 text-right">
                                                                <div class="huge">Export / Import</div>
                                                        </div>
                                                </div>
                                        </div>
                                        <div class="panel-footer">
                                                <span class="pull-left">In this page, you'll find a tool to export or import your data from/to another SexiGraf appliance. It will make the appliance update/upgrade/migration easier.</span>
                                                <div class="clearfix"></div>
                                        </div>
                                </div>
                        </a>
                </div>
        </div>
        <div class="row" style="margin:0px;padding:30px;">
                <div class="col-lg-4 col-md-6">
                        <a href="vbrcredstore.php">
                                <div class="panel panel-warning">
                                        <div class="panel-heading">
                                                <div class="row">
                                                        <div class="col-xs-2">
                                                                <i class="glyphicon glyphicon-briefcase" style="font-size: 2em;"></i>
                                                        </div>
                                                        <div class="col-xs-10 text-right">
                                                                <div class="huge">Veeam Credential Store</div>
                                                        </div>
                                                </div>
                                        </div>
                                        <div class="panel-footer">
                                                <span class="pull-left">In this section, you'll be able to manage your Veeam Backup & Replication Credential Store. This store is used to set up your Backup Server information to allow SexiGraf query what's needed.</span>
                                                <div class="clearfix"></div>
                                        </div>
                                </div>
                        </a>
                </div>
        </div>
        <script type="text/javascript" src="js/bootstrap.min.js"></script>
</body>
</html>
