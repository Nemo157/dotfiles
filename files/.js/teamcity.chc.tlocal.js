var runInMainWindow = function (fn) {
    var script = document.createElement('script');
    script.innerHTML = "(" + fn + ")();";
    document.head.appendChild(script);
};

/* global $j */

runInMainWindow(function () {
    var replaceFunc = function () {
        $j('a.branchName span').each(function () {
            var ellipses = '…';
            var current = this.textContent;
            var mouseoverText = this.onmouseover.toString();
            var branchName = mouseoverText.match(current.replace(ellipses, '.*'))[0];
            $j(this).parent().text(branchName);
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
