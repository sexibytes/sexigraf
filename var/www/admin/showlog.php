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
    <div class="navbar navbar-default navbar-fixed-top" role="navigation">
        <div class="container">
            <div class="navbar-header">
                <a class="navbar-brand" href="index.php">SexiGraf</a>
            </div>
            <div class="collapse navbar-collapse">
                <ul class="nav navbar-nav">
                    <li class="dropdown">
                        <a href="#" class="dropdown-toggle" data-toggle="dropdown">Log Files <span class="caret"></span></a>
                        <ul class="dropdown-menu" role="menu">
                            <?php foreach ($this->log as $title => $f): ?>
                            <li><a class="file" href="#<?php echo $title;?>"><?php echo $title;?></a></li>
                            <?php endforeach;?>
                        </ul>
                    </li>
                    <li><span class="navbar-text" id="grepspan"></span></li>
                    <li><span class="navbar-text" id="invertspan"></span></li>
                </ul>
                <p class="navbar-text navbar-right" id="current"></p>
            </div>
        </div>
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
    "SexiGraf Inventory" => "/var/log/sexigraf/getInventory.log",
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
