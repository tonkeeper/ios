// >>> api-runtime (generated from scripts/api/_api_runtime.js; DO NOT EDIT — run `make maestro_api_sync`)
function _httpGetJSON(url) {
    var response;
    try {
        response = http.request(url, {
            method: 'GET',
            headers: {
                'Authorization': 'Bearer ' + auth_token,
                'Content-Type': 'application/json'
            }
        });
    } catch (e) {
        throw new Error('GET ' + url + ' -> request error: ' + (e && e.message));
    }
    if (!response) {
        throw new Error('GET ' + url + ' -> no response object');
    }
    var status = (response.status !== undefined) ? response.status : 'unknown';
    console.log('[api] GET ' + url + ' -> HTTP ' + status);
    if (response.status !== undefined && (response.status < 200 || response.status >= 300)) {
        throw new Error('GET ' + url + ' -> HTTP ' + status);
    }
    if (!response.body) {
        throw new Error('GET ' + url + ' -> HTTP ' + status + ' empty body');
    }
    var parsed;
    try {
        parsed = json(response.body);
    } catch (e) {
        throw new Error('GET ' + url + ' -> HTTP ' + status + ' invalid JSON: ' + (e && e.message));
    }
    if (parsed == null) {
        throw new Error('GET ' + url + ' -> HTTP ' + status + ' null JSON body');
    }
    return parsed;
}

function _httpGetJSONOrNull(url) {
    var response;
    try {
        response = http.request(url, {
            method: 'GET',
            headers: {
                'Authorization': 'Bearer ' + auth_token,
                'Content-Type': 'application/json'
            }
        });
    } catch (e) {
        throw new Error('GET ' + url + ' -> request error: ' + (e && e.message));
    }
    if (!response) {
        throw new Error('GET ' + url + ' -> no response object');
    }
    var status = (response.status !== undefined) ? response.status : 'unknown';
    console.log('[api] GET ' + url + ' -> HTTP ' + status);
    if (response.status !== undefined) {
        if (response.status === 404) {
            return null;
        }
        if (response.status < 200 || response.status >= 300) {
            throw new Error('GET ' + url + ' -> HTTP ' + status);
        }
    }
    if (!response.body) {
        return null;
    }
    var parsed;
    try {
        parsed = json(response.body);
    } catch (e) {
        throw new Error('GET ' + url + ' -> HTTP ' + status + ' invalid JSON: ' + (e && e.message));
    }
    if (parsed == null) {
        return null;
    }
    return parsed;
}

function _sleep(ms) {
    var deadline = Date.now() + ms;
    while (Date.now() < deadline) {}
}

function _withRetry(fn, attempts, delayMs) {
    var lastErr;
    for (var i = 0; i < attempts; i++) {
        try {
            return fn();
        } catch (e) {
            lastErr = e;
            console.log('[api] attempt ' + (i + 1) + '/' + attempts + ' failed: ' + (e && e.message));
            if (delayMs > 0 && i < attempts - 1) {
                _sleep(delayMs);
            }
        }
    }
    throw new Error('[api] all ' + attempts + ' attempts failed. Last: ' + (lastErr && lastErr.message));
}
// <<< api-runtime

var lastTon = _withRetry(function () {
    var body = _httpGetJSON('https://block.tonapi.io/v2/accounts/' + addr + '/events?limit=1&subject_only=true');
    if (!body.events || body.events.length === 0) {
        throw new Error('getLastEvent: empty events for ' + addr);
    }
    var ev = body.events[0];
    if (ev.timestamp == null) {
        throw new Error('getLastEvent: latest event is missing timestamp for ' + addr);
    }
    if (!ev.actions || ev.actions.length === 0) {
        throw new Error('getLastEvent: latest event has no actions for ' + addr);
    }
    var tonTransferAction = null;
    for (var i = 0; i < ev.actions.length; i++) {
        var a = ev.actions[i];
        if (a && a.type === 'TonTransfer' && a.TonTransfer) {
            tonTransferAction = a;
            break;
        }
    }
    if (!tonTransferAction) {
        throw new Error('getLastEvent: latest event has no TonTransfer action for ' + addr);
    }
    return { timestamp: ev.timestamp, tonTransfer: tonTransferAction.TonTransfer };
}, 3);

console.log(addr);
output.tonTransfer = lastTon.tonTransfer;
output.tonTransferTimestamp = lastTon.timestamp;
