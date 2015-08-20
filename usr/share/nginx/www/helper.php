<?php

$crontabFile = "/tmp/crontab";
$crontabPath = "/etc/cron.d2/";

#function isViEnabled($inputvcenter) {
#	global $crontabFile;
#	return (preg_match("/^[^#].*ViPullStatistics\.pl --server ($inputvcenter) .* --sessionfile.*$/m", file_get_contents($crontabFile)) == 1 ? true : false);
#}

function isViEnabled($inputvcenter) {
	global $crontabPath;
	return (file_exists($crontabPath . "vi_" . str_replace(".", "_", $inputvcenter)));
}

function isVsanEnabled($inputvcenter) {
	global $crontabPath;
	return (file_exists($crontabPath . "vsan_" . str_replace(".", "_", $inputvcenter)));
#	return (preg_match("/^[^#].*VsanPullStatistics\.pl --server ($inputvcenter) .* --sessionfile.*$/m", file_get_contents($crontabFile)) == 1 ? true : false);
}

function enableVi($inputvcenter) { shell_exec("sudo /var/www/addViCrontab.sh " . $inputvcenter); }

function enableVsan($inputvcenter) { shell_exec("sudo /var/www/addVsanCrontab.sh " . $inputvcenter); }

function disableVi($inputvcenter) { shell_exec("sudo /var/www/removeViCrontab.sh " . $inputvcenter); }

function disableVsan($inputvcenter) { shell_exec("sudo /var/www/removeVsanCrontab.sh " . $inputvcenter); }

function humanFileSize($size,$unit="") {
        if( (!$unit && $size >= 1<<30) || $unit == "GB")
                return number_format($size/(1<<30),2)."GB";
        if( (!$unit && $size >= 1<<20) || $unit == "MB")
                return number_format($size/(1<<20),2)."MB";
        if( (!$unit && $size >= 1<<10) || $unit == "KB")
                return number_format($size/(1<<10),2)."KB";
        return number_format($size)." bytes";
}

function unlinkRecursive($dir) {
	if(!$dh = @opendir($dir))
        	return;
        while (false !== ($obj = readdir($dh))) {
        	if($obj == '.' || $obj == '..')
                	continue;
                if (!@unlink($dir . '/' . $obj))
                        unlinkRecursive($dir.'/'.$obj);
        }
        closedir($dh);
        @rmdir($dir);
        return;
}

function rcopy($src, $dest){
	if(!is_dir($src)) return false;
        if(!is_dir($dest))
        	if(!mkdir($dest))
                	return false;
        $i = new DirectoryIterator($src);
        foreach($i as $f) {
             	if($f->isFile())
                      	copy($f->getRealPath(), "$dest/" . $f->getFilename());
                else if(!$f->isDot() && $f->isDir())
                     	rcopy($f->getRealPath(), "$dest/$f");
        }
}

?>
