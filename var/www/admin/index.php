<?php 
session_start();
$title = "SexiGraf summary";
require("header.php");
?>
	<div class="row" style="margin:0px;padding:30px;">
                <div class="col-lg-4 col-md-6">
                	<a href="credstore.php">
				<div class="panel panel-primary">
                        		<div class="panel-heading">
                            			<div class="row">
                                			<div class="col-xs-6">
				                                <i class="glyphicon glyphicon-briefcase" style="font-size: 4em;"></i>
                                			</div>
 		                                	<div class="col-xs-6 text-right">
                                    				<div class="huge">Credential Store</div>
                                			</div>
                            			</div>
                        		</div>
                            		<div class="panel-footer">
                                		<span class="pull-left">On this section, you'll be able to manage your VMware Credential Store. This store is used to set up your vCenter information to allow SexiGraf query what's needed</span>
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
                                			<div class="col-xs-6">
                                    				<i class="glyphicon glyphicon-hdd" style="font-size: 4em;"></i>
                                			</div>
                                			<div class="col-xs-6 text-right">
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
                                <div class="panel panel-yellow">
                                        <div class="panel-heading">
                                                <div class="row">
                                                        <div class="col-xs-6">
                                                                <i class="glyphicon glyphicon-trash" style="font-size: 4em;"></i>
                                                        </div>
                                                        <div class="col-xs-6 text-right">
                                                                <div class="huge">Whisper Purge</div>
                                                        </div>
                                                </div>
                                        </div>
                                        <div class="panel-footer">
                                                <span class="pull-left">Whisper purge page will let you manage local whisper data file(s). It can be useful to remove from web-ui some corrupted/unwanted files.</span>
                                                <div class="clearfix"></div>
                                        </div>
                                </div>
                        </a>
                </div>
            </div>
</body>
</html>
