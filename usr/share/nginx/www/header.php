<!DOCTYPE HTML>
<html>
<head>
	<meta charset="utf-8">
	<title><?php echo $title; ?></title>
	<link rel="stylesheet" href="css/bootstrap.min.css">
	<link rel="stylesheet" href="css/sexigraf.css">
	<script type="text/javascript" src="/js/jquery.min.js"></script>
	<script type="text/javascript" src="/js/jquery.dropdown.js"></script>
	<script type="text/javascript" src="/js/php_file_tree_jquery.js"></script>
	<link rel="icon" type="image/x-icon" href="http://www.sexigraf.fr/favicon.ico">
	<link rel="stylesheet" id="google_fonts-css" href="//fonts.googleapis.com/css?family=Lobster%7CRaleway%3A400%2C400italic%2C700%2C700italic%7CDroid+Sans&amp;ver=4.1.1" type="text/css" media="all">
</head>
<body>
	<div id="wrapper">
        <nav class="navbar navbar-default navbar-static-top" role="navigation" style="margin-bottom: 0">
            <div class="navbar-header">
                <button type="button" class="navbar-toggle" data-toggle="collapse" data-target=".navbar-collapse">
                    <span class="sr-only">Toggle navigation</span>
                    <span class="icon-bar"></span>
                    <span class="icon-bar"></span>
                    <span class="icon-bar"></span>
                </button>
                <a class="navbar-brand" href="index.php">SexiGraf Admin Portal</a>
            </div>
            <ul class="nav navbar-top-links navbar-right">
		<li class="dropdown">
                    <a class="dropdown-toggle" data-toggle="dropdown" href="#" aria-expanded="true">
                        <i class="glyphicon glyphicon-tasks"></i>  <i class="glyphicon glyphicon-triangle-bottom" style="font-size: 0.8em;"></i>
                    </a>
                    <ul class="dropdown-menu">
			<li><a href="/index.php"><i class="glyphicon glyphicon-map-marker"></i> Summary</a></li>
                        <li class="divider"></li>
                        <li><a href="/credstore.php"><i class="glyphicon glyphicon-briefcase"></i> vSphere Credential Store</a></li>
                        <li><a href="/updater.php"><i class="glyphicon glyphicon-hdd"></i> Package Updater</a></li>
                        <li><a href="/purge.php"><i class="glyphicon glyphicon-trash"></i> Whisper Purge</a></li>
                        </li>
                    </ul>
                </li>
            </ul>
        </nav>
	</div>
