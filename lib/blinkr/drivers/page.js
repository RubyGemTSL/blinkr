var system = require('system');
var page = require('webpage').create();
var fs = require('fs');

var info = {};
info.resourceErrors = [];
info.javascriptErrors = [];
info.url = system.args[1];

var current_requests = 0;
var last_request_timeout;
var final_timeout;

page.settings = {
    loadImages: true,
    javascriptEnabled: true
};
page.settings.userAgent = 'Blinkr broken-link checker';

page.onResourceRequested = function (req) {
    current_requests += 1;
};

page.onResourceReceived = function (resp) {
    if (resp.stage === 'end') {
        current_requests -= 1;
    }
    timeout();
};

page.onResourceError = function (metadata) {
    info.resourceErrors[info.resourceErrors.length] = metadata;
}

page.onError = function (msg, trace) {
    info.javascriptErrors[info.javascriptErrors.length] = {msg: msg, trace: trace};
}

page.open(info.url, function (status) {
    if (status !== 'success') {
        exit(1);
    }
});

var exit = function exit(err_code) {
    info.content = page.content;
    // Re-read the URL in case we've been redirected
    info.url = page.url;
    system.stdout.write(JSON.stringify(info));
    if (err_code === undefined) {
        err_code = 0;
    }
    phantom.exit(err_code);
};

function timeout() {
    clearTimeout(last_request_timeout);
    clearTimeout(final_timeout);

    // If there's no more ongoing resource requests, wait for 1 seconds before
    // exiting, just in case the page kicks off another request
    if (current_requests < 1) {
        clearTimeout(final_timeout);
        last_request_timeout = setTimeout(exit, 1000);
    }

    // Sometimes, straggling requests never make it back, in which
    // case, timeout after 5 seconds and exit anyway
    // TODO record which requests timed out!
    final_timeout = setTimeout(exit, 5000);
}
