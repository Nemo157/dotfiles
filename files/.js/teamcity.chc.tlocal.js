var runInMainWindow = function (fn) {
    var script = document.createElement('script');
    script.innerHTML = "(" + fn + ")();";
    document.head.appendChild(script);
};

/* global $j */

runInMainWindow(function () {
    var replaceFunc = function () {
        var iconDataUri = 'data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiIHN0YW5kYWxvbmU9Im5vIj8+CjwhLS0gQ3JlYXRlZCB3aXRoIElua3NjYXBlIChodHRwOi8vd3d3Lmlua3NjYXBlLm9yZy8pIC0tPgoKPHN2ZwogICB4bWxuczpkYz0iaHR0cDovL3B1cmwub3JnL2RjL2VsZW1lbnRzLzEuMS8iCiAgIHhtbG5zOmNjPSJodHRwOi8vY3JlYXRpdmVjb21tb25zLm9yZy9ucyMiCiAgIHhtbG5zOnJkZj0iaHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyIKICAgeG1sbnM6c3ZnPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIKICAgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIgogICB4bWxuczpzb2RpcG9kaT0iaHR0cDovL3NvZGlwb2RpLnNvdXJjZWZvcmdlLm5ldC9EVEQvc29kaXBvZGktMC5kdGQiCiAgIHhtbG5zOmlua3NjYXBlPSJodHRwOi8vd3d3Lmlua3NjYXBlLm9yZy9uYW1lc3BhY2VzL2lua3NjYXBlIgogICB3aWR0aD0iMTAiCiAgIGhlaWdodD0iMTAiCiAgIGlkPSJzdmcyIgogICB2ZXJzaW9uPSIxLjEiCiAgIGlua3NjYXBlOnZlcnNpb249IjAuNDguNCByOTkzOSIKICAgc29kaXBvZGk6ZG9jbmFtZT0iZXh0ZXJuYWwtbGluay1sdHItaWNvbi5zdmciCiAgIGlua3NjYXBlOmV4cG9ydC1maWxlbmFtZT0iL3J1bi91c2VyLzEwMDAvZ3Zmcy9zZnRwOmhvc3Q9dXNlcnMudi1sby5rcmFrb3cucGwsdXNlcj1tNHR4L2hvbWUvV1dXL200dHgvV1dXL1dpa2ltZWRpYS9za2lucy92ZWN0b3IvaW1hZ2VzL2V4dGVybmFsLWxpbmstbHRyLWljb24ucG5nIgogICBpbmtzY2FwZTpleHBvcnQteGRwaT0iMTQ0LjEzNzI0IgogICBpbmtzY2FwZTpleHBvcnQteWRwaT0iMTQ0LjEzNzI0Ij4KICA8ZGVmcwogICAgIGlkPSJkZWZzNCI+CiAgICA8bWFya2VyCiAgICAgICBpbmtzY2FwZTpzdG9ja2lkPSJDbHViIgogICAgICAgb3JpZW50PSJhdXRvIgogICAgICAgcmVmWT0iMC4wIgogICAgICAgcmVmWD0iMC4wIgogICAgICAgaWQ9IkNsdWIiCiAgICAgICBzdHlsZT0ib3ZlcmZsb3c6dmlzaWJsZSI+CiAgICAgIDxwYXRoCiAgICAgICAgIGlkPSJwYXRoMzk5NiIKICAgICAgICAgZD0iTSAtMS41OTcxMzY3LC03LjA5Nzc2MzUgQyAtMy40ODYzODc0LC03LjA5Nzc2MzUgLTUuMDIzNTE4NywtNS41NjA2MzIxIC01LjAyMzUxODcsLTMuNjcxMzgxMyBDIC01LjAyMzUxODcsLTMuMDE0NzAxNSAtNC43ODUxNjU2LC0yLjQ0NDQ1NTYgLTQuNDY0MTA5NSwtMS45MjMyMjcxIEMgLTQuNTAyODYwOSwtMS44OTExMTU3IC00LjU0Mzc4MTQsLTEuODY0NzY0NiAtNC41ODA2NTMxLC0xLjgyOTk5MjEgQyAtNS4yMDMwNzY1LC0yLjY4NDk4NDkgLTYuMTcwMDUxNCwtMy4yNzUxMzMwIC03LjMwNzc3MzAsLTMuMjc1MTMzMCBDIC05LjE5NzAyNDUsLTMuMjc1MTMzMSAtMTAuNzM0MTU1LC0xLjczODAwMTYgLTEwLjczNDE1NSwwLjE1MTI0OTE0IEMgLTEwLjczNDE1NSwyLjA0MDQ5OTkgLTkuMTk3MDI0NSwzLjU3NzYzMTMgLTcuMzA3NzczMCwzLjU3NzYzMTMgQyAtNi4zMTQzMjY4LDMuNTc3NjMxMyAtNS40MzkxNTQwLDMuMTM1NTcwMiAtNC44MTM3NDA0LDIuNDU4ODEyNiBDIC00LjkzODQyNzQsMi44MTM3MDQxIC01LjAyMzUxODcsMy4xODAzMDAwIC01LjAyMzUxODcsMy41Nzc2MzEzIEMgLTUuMDIzNTE4Nyw1LjQ2Njg4MTkgLTMuNDg2Mzg3NCw3LjAwNDAxMzUgLTEuNTk3MTM2Nyw3LjAwNDAxMzUgQyAwLjI5MjExMzk0LDcuMDA0MDEzNSAxLjgyOTI0NTQsNS40NjY4ODE5IDEuODI5MjQ1NCwzLjU3NzYzMTMgQyAxLjgyOTI0NTQsMi43ODQyMzU0IDEuNTEzNjg2OCwyLjA4MzgwMjggMS4wNjAwNTc2LDEuNTAzMTU1MCBDIDIuNDE1MjcxOCwxLjc2NjM4NjggMy43NzE4Mzc1LDIuMjk3MzcxMSA0Ljc2NjE0NDQsMy44MzQwMjcyIEMgNC4wMjc5NDYzLDMuMDk1ODI4OSAzLjU1NDA5MDgsMS43NTM0MTE3IDMuNTU0MDkwOCwtMC4wNTg1MjkzNjEgTCAyLjkyNDc1NTQsLTAuMTA1MTQ2ODEgTCAzLjUwNzQ3MzMsLTAuMTI4NDU1NTMgQyAzLjUwNzQ3MzMsLTEuOTQwMzk2NiAzLjk1ODAxOTksLTMuMjgyODEzOCA0LjY5NjIxODMsLTQuMDIxMDEyMSBDIDMuNzM3MTI3NywtMi41Mzg3ODEzIDIuNDM5MDU0OSwtMS45OTQ2NDk2IDEuMTI5OTgzOCwtMS43MTM0NDg2IEMgMS41MzQxODAyLC0yLjI3NTM1NzggMS44MjkyNDU0LC0yLjkyNjg1NTYgMS44MjkyNDU0LC0zLjY3MTM4MTMgQyAxLjgyOTI0NTQsLTUuNTYwNjMxOSAwLjI5MjExMzk0LC03LjA5Nzc2MzUgLTEuNTk3MTM2NywtNy4wOTc3NjM1IHogIgogICAgICAgICBzdHlsZT0iZmlsbC1ydWxlOmV2ZW5vZGQ7c3Ryb2tlOiMwMDAwMDA7c3Ryb2tlLXdpZHRoOjAuNzQ1ODc5MTNwdCIKICAgICAgICAgdHJhbnNmb3JtPSJzY2FsZSgwLjYpIiAvPgogICAgPC9tYXJrZXI+CiAgICA8bWFya2VyCiAgICAgICBpbmtzY2FwZTpzdG9ja2lkPSJEaWFtb25kTSIKICAgICAgIG9yaWVudD0iYXV0byIKICAgICAgIHJlZlk9IjAuMCIKICAgICAgIHJlZlg9IjAuMCIKICAgICAgIGlkPSJEaWFtb25kTSIKICAgICAgIHN0eWxlPSJvdmVyZmxvdzp2aXNpYmxlIj4KICAgICAgPHBhdGgKICAgICAgICAgaWQ9InBhdGgzODQ5IgogICAgICAgICBkPSJNIDAsLTcuMDcxMDc2OCBMIC03LjA3MTA4OTQsMCBMIDAsNy4wNzEwNTg5IEwgNy4wNzEwNDYyLDAgTCAwLC03LjA3MTA3NjggeiAiCiAgICAgICAgIHN0eWxlPSJmaWxsLXJ1bGU6ZXZlbm9kZDtzdHJva2U6IzAwMDAwMDtzdHJva2Utd2lkdGg6MS4wcHQiCiAgICAgICAgIHRyYW5zZm9ybT0ic2NhbGUoMC40KSIgLz4KICAgIDwvbWFya2VyPgogICAgPG1hcmtlcgogICAgICAgaW5rc2NhcGU6c3RvY2tpZD0iQXJyb3cxTHN0YXJ0IgogICAgICAgb3JpZW50PSJhdXRvIgogICAgICAgcmVmWT0iMC4wIgogICAgICAgcmVmWD0iMC4wIgogICAgICAgaWQ9IkFycm93MUxzdGFydCIKICAgICAgIHN0eWxlPSJvdmVyZmxvdzp2aXNpYmxlIj4KICAgICAgPHBhdGgKICAgICAgICAgaWQ9InBhdGgzNzY3IgogICAgICAgICBkPSJNIDAuMCwwLjAgTCA1LjAsLTUuMCBMIC0xMi41LDAuMCBMIDUuMCw1LjAgTCAwLjAsMC4wIHogIgogICAgICAgICBzdHlsZT0iZmlsbC1ydWxlOmV2ZW5vZGQ7c3Ryb2tlOiMwMDAwMDA7c3Ryb2tlLXdpZHRoOjEuMHB0IgogICAgICAgICB0cmFuc2Zvcm09InNjYWxlKDAuOCkgdHJhbnNsYXRlKDEyLjUsMCkiIC8+CiAgICA8L21hcmtlcj4KICA8L2RlZnM+CiAgPHNvZGlwb2RpOm5hbWVkdmlldwogICAgIGlkPSJiYXNlIgogICAgIHBhZ2Vjb2xvcj0iI2ZmZmZmZiIKICAgICBib3JkZXJjb2xvcj0iIzY2NjY2NiIKICAgICBib3JkZXJvcGFjaXR5PSIxLjAiCiAgICAgaW5rc2NhcGU6cGFnZW9wYWNpdHk9IjAuMCIKICAgICBpbmtzY2FwZTpwYWdlc2hhZG93PSIyIgogICAgIGlua3NjYXBlOnpvb209IjIyLjYyNzQxNyIKICAgICBpbmtzY2FwZTpjeD0iMTEuNzI1MzEyIgogICAgIGlua3NjYXBlOmN5PSI1LjY3ODAxNTkiCiAgICAgaW5rc2NhcGU6ZG9jdW1lbnQtdW5pdHM9InB4IgogICAgIGlua3NjYXBlOmN1cnJlbnQtbGF5ZXI9ImxheWVyMSIKICAgICBzaG93Z3JpZD0iZmFsc2UiCiAgICAgZml0LW1hcmdpbi10b3A9IjAiCiAgICAgZml0LW1hcmdpbi1sZWZ0PSIwIgogICAgIGZpdC1tYXJnaW4tcmlnaHQ9IjAiCiAgICAgZml0LW1hcmdpbi1ib3R0b209IjAiCiAgICAgaW5rc2NhcGU6d2luZG93LXdpZHRoPSIxOTIwIgogICAgIGlua3NjYXBlOndpbmRvdy1oZWlnaHQ9IjEwNDEiCiAgICAgaW5rc2NhcGU6d2luZG93LXg9IjAiCiAgICAgaW5rc2NhcGU6d2luZG93LXk9IjAiCiAgICAgaW5rc2NhcGU6d2luZG93LW1heGltaXplZD0iMSIgLz4KICA8bWV0YWRhdGEKICAgICBpZD0ibWV0YWRhdGE3Ij4KICAgIDxyZGY6UkRGPgogICAgICA8Y2M6V29yawogICAgICAgICByZGY6YWJvdXQ9IiI+CiAgICAgICAgPGRjOmZvcm1hdD5pbWFnZS9zdmcreG1sPC9kYzpmb3JtYXQ+CiAgICAgICAgPGRjOnR5cGUKICAgICAgICAgICByZGY6cmVzb3VyY2U9Imh0dHA6Ly9wdXJsLm9yZy9kYy9kY21pdHlwZS9TdGlsbEltYWdlIiAvPgogICAgICAgIDxkYzp0aXRsZT48L2RjOnRpdGxlPgogICAgICA8L2NjOldvcms+CiAgICA8L3JkZjpSREY+CiAgPC9tZXRhZGF0YT4KICA8ZwogICAgIGlua3NjYXBlOmxhYmVsPSJMYXllciAxIgogICAgIGlua3NjYXBlOmdyb3VwbW9kZT0ibGF5ZXIiCiAgICAgaWQ9ImxheWVyMSIKICAgICB0cmFuc2Zvcm09InRyYW5zbGF0ZSgtODI2LjQyODU5LC02OTguNzkwNzcpIj4KICAgIDxyZWN0CiAgICAgICBzdHlsZT0iZmlsbDojZmZmZmZmO3N0cm9rZTojMDA2NmNjO3N0cm9rZS13aWR0aDoxcHg7c3Ryb2tlLWxpbmVjYXA6YnV0dDtzdHJva2UtbGluZWpvaW46bWl0ZXI7c3Ryb2tlLW9wYWNpdHk6MTtmaWxsLW9wYWNpdHk6MSIKICAgICAgIGlkPSJyZWN0Mjk5NiIKICAgICAgIHdpZHRoPSI1Ljk4MjE0MjkiCiAgICAgICBoZWlnaHQ9IjUuOTgyMTQyOSIKICAgICAgIHg9IjgyNi45Mjg1OSIKICAgICAgIHk9IjcwMi4zMDg2NSIKICAgICAgIGlua3NjYXBlOmV4cG9ydC1maWxlbmFtZT0iL2hvbWUvbTR0eC9QdWxwaXQvZWhlaGVoLnBuZyIKICAgICAgIGlua3NjYXBlOmV4cG9ydC14ZHBpPSI5MC4wODU3NzciCiAgICAgICBpbmtzY2FwZTpleHBvcnQteWRwaT0iOTAuMDg1Nzc3IiAvPgogICAgPGcKICAgICAgIGlkPSJnNDgxNSIKICAgICAgIHRyYW5zZm9ybT0ibWF0cml4KDAuNzA3MTA2NzgsMC43MDcxMDY3OCwtMC43MDcxMDY3OCwwLjcwNzEwNjc4LDc2Mi44NywtMzU5Ljg4MzM5KSIKICAgICAgIGlua3NjYXBlOmV4cG9ydC1maWxlbmFtZT0iL2hvbWUvbTR0eC9QdWxwaXQvZWhlaGVoLnBuZyIKICAgICAgIGlua3NjYXBlOmV4cG9ydC14ZHBpPSI5MC4wODU3NzciCiAgICAgICBpbmtzY2FwZTpleHBvcnQteWRwaT0iOTAuMDg1Nzc3Ij4KICAgICAgPHBhdGgKICAgICAgICAgc29kaXBvZGk6bm9kZXR5cGVzPSJjY2NjY2NjY2NjIgogICAgICAgICBpbmtzY2FwZTpjb25uZWN0b3ItY3VydmF0dXJlPSIwIgogICAgICAgICBpZD0icGF0aDQ3NzciCiAgICAgICAgIGQ9Im0gNzk2LjkwODE5LDcwMC4yODMxNyAzLjcwMTI3LC0zLjcwMTI2IDMuODExNzQsMy44MTE3NSAtMC4wMTg5LDIuMjAzMzYgLTEuODUyMzQsMCAwLDMuODU0MyAtMy44MDIzMywwIDAsLTMuOTcxMDggLTEuODUzNiwwIHoiCiAgICAgICAgIHN0eWxlPSJmaWxsOiMwMDY2ZmY7ZmlsbC1vcGFjaXR5OjE7c3Ryb2tlOm5vbmUiIC8+CiAgICAgIDxwYXRoCiAgICAgICAgIHNvZGlwb2RpOm5vZGV0eXBlcz0iY2NjY2NjY2MiCiAgICAgICAgIGlua3NjYXBlOmNvbm5lY3Rvci1jdXJ2YXR1cmU9IjAiCiAgICAgICAgIGlkPSJwYXRoNDc3OSIKICAgICAgICAgZD0ibSA4MDAuNjA5NDYsNjk4LjAwMjQ0IDMuNDY5ODYsMy40Mzg2NSAtMi41NzAyLDAgMCw0LjA3NDM2IC0xLjczNjIsMCAwLC00LjA3NDM2IC0yLjYxNzU0LC0zLjZlLTQgeiIKICAgICAgICAgc3R5bGU9ImZpbGw6I2ZmZmZmZjtmaWxsLW9wYWNpdHk6MTtzdHJva2U6bm9uZSIgLz4KICAgIDwvZz4KICA8L2c+Cjwvc3ZnPgo=';

        $j('a.branchName span').each(function () {
            var ellipses = '…';
            var current = this.textContent;
            var mouseoverText = this.onmouseover.toString();
            var branchName = mouseoverText.match(current.replace(ellipses, '.*'))[0];
            $j(this).parent().text(branchName);
        });
        $j('td.branch.hasBranch a.branchName:only-child:not(:has(span))').each(function () {
            var branchName = this.textContent;
            var link = $j('<a>').attr('href', 'http://routedev.chc.tlocal/' + branchName.replace(/^([A-Za-z]\w*)_\d+$/, '$1') + '/').css({
                'background-position': 'center right',
                'background-repeat': 'no-repeat',
                'background-image': 'linear-gradient(transparent,transparent),url(' + iconDataUri + ')',
                'padding-right': '13px',
                'margin-right': '5px'
            });
            $j(this).parent().prepend(link);
        });
        $j('td.branch:not(.hasBranch):not(:has(a))').each(function () {
            var branchName = 'default';
            var link = $j('<a>').attr('href', 'http://routedev.chc.tlocal/' + branchName.replace(/^([A-Za-z]\w*)_\d+$/, '$1') + '/').css({
                'background-position': 'center right',
                'background-repeat': 'no-repeat',
                'background-image': 'linear-gradient(transparent,transparent),url(' + iconDataUri + ')',
                'padding-right': '13px',
                'margin-right': '5px',
                'margin-left': '2em'
            });
            $j(this).prepend(link);
        });
    };

    var quickInterval = window.setInterval(function () {
        if ($j('a.branchName span')) {
            replaceFunc();
            window.clearInterval(quickInterval);
        }
    }, 50);

    window.setInterval(replaceFunc, 1000);
});
