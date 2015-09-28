<?php 
session_start();
$title = "SexiGraf summary";
require("header.php");
?>
	<div class="row" style="margin:0px;padding:30px;">
                <div class="col-lg-3 col-md-6">
                	<a href="credstore.php">
				<div class="panel panel-primary">
                        		<div class="panel-heading">
                            			<div class="row">
                                			<div class="col-xs-3">
				                                <i class="glyphicon glyphicon-briefcase" style="font-size: 4em;"></i>
                                			</div>
 		                                	<div class="col-xs-9 text-right">
                                    				<div class="huge">Credential Store</div>
                                			</div>
                            			</div>
                        		</div>
                            		<div class="panel-footer">
                                		<span class="pull-left">In this section, you'll be able to manage your VMware Credential Store. This store is used to set up your vCenter information to allow SexiGraf query what's needed.</span>
                                		<div class="clearfix"></div>
                            		</div>
                    		</div>
                        </a>
                </div>
                <div class="col-lg-3 col-md-6">
                        <a href="updater.php">
                    		<div class="panel panel-green">
                        		<div class="panel-heading">
                            			<div class="row">
                                			<div class="col-xs-3">
                                    				<i class="glyphicon glyphicon-hdd" style="font-size: 4em;"></i>
                                			</div>
                                			<div class="col-xs-9 text-right">
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
		<div class="col-lg-3 col-md-6">
                        <a href="purge.php">
                                <div class="panel panel-red">
                                        <div class="panel-heading">
                                                <div class="row">
                                                        <div class="col-xs-3">
                                                                <i class="glyphicon glyphicon-trash" style="font-size: 4em;"></i>
                                                        </div>
                                                        <div class="col-xs-9 text-right">
                                                                <div class="huge">Stats Remover</div>
                                                        </div>
                                                </div>
                                        </div>
                                        <div class="panel-footer">
                                                <span class="pull-left">The Stats Remover page will let you manage Graphite data (Whisper files). It can be useful to remove from web-ui the legacy or orphaned stats (i.e. after datastore removal).</span>
                                                <div class="clearfix"></div>
                                        </div>
                                </div>
                        </a>
                </div>
                <div class="col-lg-3 col-md-6">
                        <a href="refresh-inventory.php">
                                <div class="panel panel-yellow">
                                        <div class="panel-heading">
                                                <div class="row">
                                                        <div class="col-xs-3">
                                                                <i class="glyphicon glyphicon-th-list" style="font-size: 4em;"></i>
                                                        </div>
                                                        <div class="col-xs-9 text-right">
                                                                <div class="huge">Refresh Inventory</div>
                                                        </div>
                                                </div>
                                        </div>
                                        <div class="panel-footer">
                                                <span class="pull-left">The Static Offline Inventory is automatically schedule to be updated every 6 hours. If you want to force a refresh, you can use this section to perform update.</span>
                                                <div class="clearfix"></div>
                                        </div>
                                </div>
                        </a>
                </div>
            </div>
</body>
</html>
