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
