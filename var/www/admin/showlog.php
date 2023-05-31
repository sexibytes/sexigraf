<?php

class PHPTail {
    /* Source: https://github.com/taktos/php-tail */

    /**
     * Location of the log file we're tailing
     * @var string
     */
    private $log = "";
    /**
     * The time between AJAX requests to the server.
     *
     * Setting this value too high with an extremly fast-filling log will cause your PHP application to hang.
     * @var integer
     */
    private $updateTime;
    /**
     * This variable holds the maximum amount of bytes this application can load into memory (in bytes).
     * @var string
     */
    private $maxSizeToLoad;
    /**
     *
     * PHPTail constructor
     * @param string $log the location of the log file
     * @param integer $defaultUpdateTime The time between AJAX requests to the server.
     * @param integer $maxSizeToLoad This variable holds the maximum amount of bytes this application can load into memory (in bytes). Default is 2 Megabyte = 2097152 byte
     */
    public function __construct($log, $defaultUpdateTime = 2000, $maxSizeToLoad = 2097152) {
        $this->log = is_array($log) ? $log : array($log);
        $this->updateTime = $defaultUpdateTime;
        $this->maxSizeToLoad = $maxSizeToLoad;
    }
    /**
     * This function is in charge of retrieving the latest lines from the log file
     * @param string $lastFetchedSize The size of the file when we lasted tailed it.
     * @param string $grepKeyword The grep keyword. This will only return rows that contain this word
     * @return Returns the JSON representation of the latest file size and appended lines.
     */
    public function getNewLines($file, $lastFetchedSize, $grepKeyword, $invert) {

        /**
         * Clear the stat cache to get the latest results
         */
        clearstatcache();
        /**
         * Define how much we should load from the log file
         * @var
         */
        if(empty($file)) {
            $file = key(array_slice($this->log, 0, 1, true));
        }
        $fsize = filesize($this->log[$file]);
        $maxLength = ($fsize - $lastFetchedSize);
        /**
         * Verify that we don't load more data then allowed.
         */
        if($maxLength > $this->maxSizeToLoad) {
            $maxLength = ($this->maxSizeToLoad / 2);
        }
        /**
         * Actually load the data
         */
        $data = array();
        if($maxLength > 0) {

            $fp = fopen($this->log[$file], 'r');
            fseek($fp, -$maxLength , SEEK_END);
            $data = explode("\n", fread($fp, $maxLength));

        }
        /**
         * Run the grep function to return only the lines we're interested in.
         */
        if($invert == 0) {
            $data = preg_grep("/$grepKeyword/",$data);
        }
        else {
            $data = preg_grep("/$grepKeyword/",$data, PREG_GREP_INVERT);
        }
        /**
         * If the last entry in the array is an empty string lets remove it.
         */
        if(end($data) == "") {
            array_pop($data);
        }
        return json_encode(array("size" => $fsize, "file" => $this->log[$file], "data" => $data));
    }
    /**
     * This function will print out the required HTML/CSS/JS
     */
    public function generateGUI() {
        ?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SexiGraf Log Viewer</title>

<link rel="stylesheet" href="css/bootstrap.min.css">
<link rel="stylesheet" href="css/sexigraf.css">

<!-- HTML5 Shim and Respond.js IE8 support of HTML5 elements and media queries -->
<!-- WARNING: Respond.js doesn't work if you view the page via file:// -->
<!--[if lt IE 9]>
    <script src="https://oss.maxcdn.com/html5shiv/3.7.2/html5shiv.min.js"></script>
    <script src="https://oss.maxcdn.com/respond/1.4.2/respond.min.js"></script>
<![endif]-->

<script src="js/jquery.min.js"></script>

<script type="text/javascript">
    /* <![CDATA[ */
    //Last know size of the file
    lastSize = 0;
    //Grep keyword
    grep = "";
    //Should the Grep be inverted?
    invert = 0;
    //Last known document height
    documentHeight = 0;
    //Last known scroll position
    scrollPosition = 0;
    //Should we scroll to the bottom?
    scroll = true;
    lastFile = window.location.hash != "" ? window.location.hash.substr(1) : "";
    console.log(lastFile);
    $(document).ready(function() {

        $(".file").click(function(e) {
            $("#results").text("");
            lastSize = 0;
console.log(e);
            lastFile = $(e.target).text();
        });

        //Set up an interval for updating the log. Change updateTime in the PHPTail contstructor to change this
        setInterval("updateLog()", <?php echo $this->updateTime; ?>);
        //Some window scroll event to keep the menu at the top
        $(window).scroll(function(e) {
            if ($(window).scrollTop() > 0) {
                $('.float').css({
                    position : 'fixed',
                    top : '0',
                    left : 'auto'
                });
            } else {
                $('.float').css({
                    position : 'static'
                });
            }
        });
        //If window is resized should we scroll to the bottom?
        $(window).resize(function() {
            if (scroll) {
                scrollToBottom();
            }
        });
        //Handle if the window should be scrolled down or not
        $(window).scroll(function() {
            documentHeight = $(document).height();
            scrollPosition = $(window).height() + $(window).scrollTop();
            if (documentHeight <= scrollPosition) {
                scroll = true;
            } else {
                scroll = false;
            }
        });
        scrollToBottom();

    });
    //This function scrolls to the bottom
    function scrollToBottom() {
        $("html, body").animate({scrollTop: $(document).height()}, "fast");
    }
    //This function queries the server for updates.
    function updateLog() {
        $.getJSON('?ajax=1&file=' + lastFile + '&lastsize=' + lastSize + '&grep=' + grep + '&invert=' + invert, function(data) {
            lastSize = data.size;
            $("#current").text(data.file);
            $.each(data.data, function(key, value) {
                $("#results").append('' + value + '<br/>');
            });
            if (scroll) {
                scrollToBottom();
            }
        });
    }
    /* ]]> */
</script>
</head>
<body>
        <div id="wrapper">
        <nav class="navbar navbar-default navbar-fixed-top" role="navigation" style="margin-bottom: 0">
                <div class="navbar-header">
                        <button type="button" class="navbar-toggle" data-toggle="collapse" data-target=".navbar-collapse">
                                <span class="sr-only">Toggle navigation</span>
                                <span class="icon-bar"></span>
                                <span class="icon-bar"></span>
                                <span class="icon-bar"></span>
                        </button>
                </div>
                <p class="navbar-text navbar-left" style="padding-top: 0px;" id="current"></p>
                <ul class="nav navbar-top-links navbar-right">
                        <li>
                                <a class="dropdown-toggle" data-toggle="dropdown" href="#" aria-expanded="true">
                                        <i class="glyphicon glyphicon-file"></i>  <i class="glyphicon glyphicon-triangle-bottom" style="font-size: 0.8em;"></i>
                                </a>
                                <ul class="dropdown-menu">
                                                <?php foreach ($this->log as $title => $f): ?>
                                                <li><a class="file" href="#<?php echo $title;?>"><?php echo $title;?></a></li>
                                                <?php endforeach;?>
                                </ul>
                        </li>
                        <li><i class="glyphicon glyphicon-option-vertical" style="color: #BBB;"></i></li>
                        <li>
                                <a class="dropdown-toggle" href="index.php"><i class="glyphicon glyphicon-home"></i></a>
                        </li>
                        <li class="dropdown">
                                <a class="dropdown-toggle" data-toggle="dropdown" href="#" aria-expanded="true">
                                        <i class="glyphicon glyphicon-tasks"></i>  <i class="glyphicon glyphicon-triangle-bottom" style="font-size: 0.8em;"></i>
                                </a>
                                <ul class="dropdown-menu">
                                        <li><a href="index.php"><i class="glyphicon glyphicon-map-marker glyphicon-custom"></i> Summary</a></li>
                                        <li class="divider"></li>
                                        <li><a href="credstore.php"><i class="glyphicon glyphicon-briefcase glyphicon-custom"></i> vSphere Credential Store</a></li>
                                        <li><a href="vbrcredstore.php"><i class="glyphicon glyphicon-briefcase glyphicon-custom"></i> Veeam Credential Store</a></li>
                                        <li><a href="updater.php"><i class="glyphicon glyphicon-hdd glyphicon-custom"></i> Package Updater</a></li>
                                        <li><a href="purge.php"><i class="glyphicon glyphicon-trash glyphicon-custom"></i> Stats Remover</a></li>
                                        <li><a href="refresh-inventory.php"><i class="glyphicon glyphicon-th-list glyphicon-custom"></i> Refresh Inventory</a></li>
                                        <li><a href="showlog.php"><i class="glyphicon glyphicon-search glyphicon-custom"></i> Log Viewer</a></li>
                                        <li><a href="export-import.php"><i class="glyphicon glyphicon-transfer glyphicon-custom"></i> Export / Import</a></li>
                                </ul>
                        </li>
            </ul>
        </nav>
        </div>

        <div class="contents">
                <div id="results" class="results"></div>
        </div>
        <script src="js/bootstrap.min.js"></script>
</body>
</html>
        <?php
    }
}

/**
 * Initilize a new instance of PHPTail
 * @var PHPTail
 */

$tail = new PHPTail(array(
    "VI Offline Inventory" => "/var/log/sexigraf/ViOfflineInventory.log",
    "vSAN Statistics" => "/var/log/sexigraf/VsanDisksPullStatistics.log",
    "VI Statistics" => "/var/log/sexigraf/ViPullStatistics.log",
    "VBR Statistics" => "/var/log/sexigraf/VbrPullStatistics.log",
));

/**
 * We're getting an AJAX call
 */
if(isset($_GET['ajax']))  {
    echo $tail->getNewLines($_GET['file'], $_GET['lastsize'], $_GET['grep'], $_GET['invert']);
    die();
}

/**
 * Regular GET/POST call, print out the GUI
 */
$tail->generateGUI();
?>
