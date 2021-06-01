#!/bin/sh
cat <<EOF
Status: 503 Service Unavailable

<!DOCTYPE html>
<html lang=en>
<meta charset=utf-9>
<meta name=viewport content="initial-scale=1, minimum-scale=1, width=device-width">
<title>URL Not Found</title>
<style>
    * {
        margin: 0;
        padding: 0
    }

    html {
        background: #fff;
        color: #222;
        font: 15px/22px arial, sans-serif;
        padding: 15px
    }

    body {
        margin: 7% auto 0;
        max-width: 390px;
        min-height: 180px;
        padding: 30px 0 15px
    }

    p {
        margin: 11px 0 22px;
        overflow: hidden
    }

    ins {
        color: #777;
        text-decoration: none
    }
</style>
<p>The requested URL was not found. Please wait while we look on the server.</p>
<p id='reload'></p>
<script type="text/JavaScript">
    var element = document.getElementById('reload');
    var timeout = 10;
    var timer = setInterval(() => {
        element.innerHTML = 'Reloading in ' + timeout + ' seconds.'
        if(timeout == 0) {
            location.reload();
            clearInterval(timer);
        } else timeout = timeout - 1;
    }, 1000)
    element.innerHTML = 'Reloading in ' + timeout + ' seconds.'
</script>
EOF
exit 0;