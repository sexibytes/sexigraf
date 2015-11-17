<?php

$crontabFile = "/tmp/crontab";
$crontabPath = "/etc/cron.d/";

function isViEnabled($inputvcenter) {
        global $crontabPath;
        return (file_exists($crontabPath . "vi_" . str_replace(".", "_", $inputvcenter)));
}

function isVsanEnabled($inputvcenter) {
        global $crontabPath;
        return (file_exists($crontabPath . "vsan_" . str_replace(".", "_", $inputvcenter)));
}

function enableVi($inputvcenter) { shell_exec("sudo /bin/bash /var/www/scripts/addViCrontab.sh " . $inputvcenter); }

function enableVsan($inputvcenter) { shell_exec("sudo /bin/bash /var/www/scripts/addVsanCrontab.sh " . $inputvcenter); }

function disableVi($inputvcenter) { shell_exec("sudo /bin/bash /var/www/scripts/removeViCrontab.sh " . $inputvcenter); }

function disableVsan($inputvcenter) { shell_exec("sudo /bin/bash /var/www/scripts/removeVsanCrontab.sh " . $inputvcenter); }

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

function php_file_tree_dir($directory, $first_call = true) {
        $file = scandir($directory);
        natcasesort($file);
        $files = $dirs = array();
        foreach($file as $this_file) {
                if( is_dir("$directory/$this_file" ) ) $dirs[] = $this_file; else $files[] = $this_file;
        }
        $file = array_merge($dirs, $files);

        if( count($file) > 2 ) {
                $php_file_tree = "<ul";
                if( $first_call ) { $php_file_tree .= " class=\"php-file-tree\""; $first_call = false; }
                $php_file_tree .= ">";
                foreach( $file as $this_file ) {
                        if( $this_file != "." && $this_file != ".." ) {
                                if( is_dir("$directory/$this_file") ) {
                                        $php_file_tree .= "<li class=\"pft-directory\"><input type=\"checkbox\" name=\"pathChecked[]\" value=\"$directory/$this_file\"> <a href=\"#\"><strong>" . htmlspecialchars($this_file) . "</strong></a>";
                                        $php_file_tree .= php_file_tree_dir("$directory/$this_file" , false);
                                        $php_file_tree .= "</li>";
                                } else {
                                        $php_file_tree .= "<li class=\"pft-file\"><input type=\"checkbox\" name=\"pathChecked[]\" value=\"$directory/$this_file\"> <strong>" . htmlspecialchars($this_file) . "</strong> (". humanFileSize(filesize("$directory/$this_file")) . ")</li>";
                                }
                        }
                }
                $php_file_tree .= "</ul>";
        }
        return $php_file_tree;
}

function php_file_tree($directory, $extension) {
        $file = scandir($directory);
        natcasesort($file);
        $files = array();
        foreach($file as $this_file) {
                if( !is_dir("$directory/$this_file") && pathinfo("$directory/$this_file", PATHINFO_EXTENSION) == $extension) $files[] = $this_file;
        }
        if( count($files) > 0 ) {
                $php_file_tree = "<ul class=\"php-file-tree\">";
                foreach( $files as $this_file ) {
                        if( $this_file != "." && $this_file != ".." ) {
                                $php_file_tree .= "<li class=\"pft-file\"><input type=\"checkbox\" name=\"pathChecked[]\" value=\"$directory/$this_file\"> <strong>" . htmlspecialchars($this_file) . "</strong> (". humanFileSize(filesize("$directory/$this_file")) . ")</li>";
                        }
                }
                $php_file_tree .= "</ul>";
        }
        return $php_file_tree;
}

function php_file_tree_top_oldest($directory, $topn) {
        $display = array('wsp');
        $files = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($directory));
        $data = array();
        foreach($files as $file) {
                $time = DateTime::createFromFormat('U', filemtime($file->getPathname()));
                if(in_array($file->getExtension(), $display)) {
                        $data[] = array('filename' => $file->getPathname(), 'size' => $file->getSize(), 'time' => $time->getTimestamp());
                }
        }
        usort($data, function($a, $b){ // sort by time oldest
                return $a['time'] - $b['time'];
        });

        $i = 0;
        $php_file_tree = "<ul class=\"php-file-tree\">";
        foreach ($data as $key => $value) {
                if (++$i == $topn) break;
                $time = date('Y-m-d H:i:s', $value['time']);
                $php_file_tree .= "<li class=\"pft-file\"><input type=\"checkbox\" name=\"pathChecked[]\" value=\"$value[filename]\"> <strong>" . htmlspecialchars(str_replace($directory."/", "", $value[filename])) . "</strong> (". humanFileSize($value['size']) . " | $time)</li>";
        }
        $php_file_tree .= "</ul>";
        return $php_file_tree;
}

?>
