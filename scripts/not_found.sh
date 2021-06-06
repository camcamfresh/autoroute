#!/bin/sh
cat <<EOF
Status: 404 Not Found

<!DOCTYPE html>
<html lang=en>
<meta charset=utf-9>
<meta name=viewport content="initial-scale=1, minimum-scale=1, width=device-width">
<title>Error 404 Not Found</title>
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
<p><b>Error 404</b> The requested URL was not found on this server.</p>
EOF
exit 0;