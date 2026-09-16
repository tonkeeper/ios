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

function _toNanoString(decimalAmount, decimals) {
    var s = String(decimalAmount).trim();
    if (!/^\d+(\.\d+)?$/.test(s)) {
        throw new Error('expectedAmount must be a non-negative decimal string, got "' + s + '"');
    }
    var dot = s.indexOf('.');
    var integerPart = dot === -1 ? s : s.substring(0, dot);
    var fractionPart = dot === -1 ? '' : s.substring(dot + 1);
    if (fractionPart.length > decimals) {
        throw new Error(
            'expectedAmount has more fraction digits than token decimals (' + decimals + '): "' + s + '"'
        );
    }
    var paddedFraction = fractionPart + new Array(decimals - fractionPart.length + 1).join('0');
    var nano = (integerPart === '' ? '0' : integerPart) + paddedFraction;
    nano = nano.replace(/^0+/, '');
    return nano === '' ? '0' : nano;
}

var FEE_COMMENT = 'Call: TonkeeperRelayerFee';

var result = _withRetry(function () {
    var body = _httpGetJSON('https://block.tonapi.io/v2/accounts/' + addr + '/events?limit=1&subject_only=true');
    if (!body.events || body.events.length === 0) {
        throw new Error('getLastSentJettonTransferEvent: empty events for ' + addr);
    }
    var ev = body.events[0];
    if (!ev.actions || ev.actions.length === 0) {
        throw new Error('getLastSentJettonTransferEvent: latest event has no actions for ' + addr);
    }
    var primary = null;
    var fee = null;
    for (var i = 0; i < ev.actions.length; i++) {
        var a = ev.actions[i];
        if (!a || a.status !== 'ok') continue;
        if (a.type !== 'JettonTransfer' || !a.JettonTransfer) continue;
        var t = a.JettonTransfer;
        if (!t.jetton || t.jetton.symbol !== expectedSymbol) continue;
        if (t.comment === FEE_COMMENT) {
            if (fee == null) fee = t;
        } else {
            if (primary == null) primary = t;
        }
    }
    if (!primary) {
        throw new Error(
            'getLastSentJettonTransferEvent: no primary ' + expectedSymbol +
            ' JettonTransfer (without "' + FEE_COMMENT + '" comment) for ' + addr
        );
    }
    if (!fee) {
        throw new Error(
            'getLastSentJettonTransferEvent: no fee JettonTransfer (comment "' + FEE_COMMENT + '") for ' + addr
        );
    }
    var decimals = Number(primary.jetton.decimals);
    if (!isFinite(decimals)) {
        throw new Error('getLastSentJettonTransferEvent: primary jetton missing decimals for ' + addr);
    }
    var expectedNano = _toNanoString(expectedAmount, decimals);
    if (String(primary.amount) !== expectedNano) {
        throw new Error(
            'getLastSentJettonTransferEvent: primary amount mismatch. expected=' + expectedNano +
            ' (= ' + expectedAmount + ' * 10^' + decimals + '), got=' + String(primary.amount)
        );
    }
    return { timestamp: ev.timestamp, primary: primary, fee: fee };
}, 3);

output.lastSentJettonTransferTimestamp = result.timestamp;
output.lastSentJettonTransferPrimary = result.primary;
output.lastSentJettonTransferFee = result.fee;
