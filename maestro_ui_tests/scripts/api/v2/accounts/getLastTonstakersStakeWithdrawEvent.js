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

var _freshWithinSec = 0;
if (typeof fresh_within_sec !== 'undefined' && fresh_within_sec) {
    _freshWithinSec = parseInt(fresh_within_sec, 10) || 0;
}

var _eventsLimit = 15;
if (typeof events_limit !== 'undefined' && events_limit) {
    _eventsLimit = parseInt(events_limit, 10) || 15;
}

var _pollAttempts = 8;
if (typeof poll_attempts !== 'undefined' && poll_attempts) {
    _pollAttempts = parseInt(poll_attempts, 10) || 8;
}

var _pollDelayMs = 12000;
if (typeof poll_delay_ms !== 'undefined' && poll_delay_ms) {
    _pollDelayMs = parseInt(poll_delay_ms, 10) || 12000;
}

var stake = _withRetry(function () {
    var body = _httpGetJSON(
        'https://block.tonapi.io/v2/accounts/' + addr + '/events?limit=' + _eventsLimit + '&subject_only=true'
    );
    if (!body.events || body.events.length === 0) {
        throw new Error('getLastTonstakersStakeWithdrawEvent: empty events for ' + addr);
    }
    var nowSec = Math.floor(Date.now() / 1000);
    for (var i = 0; i < body.events.length; i++) {
        var ev = body.events[i];
        if (!ev.actions) {
            continue;
        }
        if (_freshWithinSec > 0 && Number(ev.timestamp) < nowSec - _freshWithinSec) {
            continue;
        }
        for (var j = 0; j < ev.actions.length; j++) {
            var a = ev.actions[j];
            if (a.status !== 'ok') {
                continue;
            }
            if (a.type === 'WithdrawStakeRequest' && a.WithdrawStakeRequest) {
                var wr = a.WithdrawStakeRequest;
                if (wr.implementation === 'liquidTF' && wr.pool && wr.pool.name === 'Tonstakers') {
                    var meta = wr.stake_meta;
                    if (!meta || meta.value == null || meta.decimals == null || meta.token_name !== 'tsTON') {
                        continue;
                    }
                    return meta;
                }
            }
        }
    }
    throw new Error(
        'getLastTonstakersStakeWithdrawEvent: no WithdrawStakeRequest(liquidTF,Tonstakers,tsTON) in last ' +
            _eventsLimit +
            ' events for ' +
            addr +
            (_freshWithinSec > 0 ? ' (fresh within ' + _freshWithinSec + 's)' : '')
    );
}, _pollAttempts, _pollDelayMs);

output.tonstakersWithdrawTsTonAmount = String(stake.value);
output.tonstakersWithdrawTsTonDecimals = Number(stake.decimals);
