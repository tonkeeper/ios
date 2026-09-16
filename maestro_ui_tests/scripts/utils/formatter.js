/**
 * Mirrors KeeperCore `AmountFormatter` (default `.compact`) for integer minor-unit amounts.
 * Uses string math only (no `Number` scaling) so large nano-ton values stay exact.
 * Locale fixed to en-style: '.' decimal separator, ' ' (U+0020) thousands grouping — same as
 * `AmountFormatter.Configuration` grouping + en simulator in CI.
 * Sign↔number gap is always the thin space (U+2009) — `AmountFormatter` uses `config.space`
 * (`FormattersAssembly` sets it to `String.Symbol.shortSpace`). Number↔symbol gap follows
 * `AmountFormatter.space(for:)`: a regular space for ASCII-Latin symbols (GRAM, tsTON), thin otherwise.
 */

var THIN_SPACE = '\u2009';
var PLUS_SIGN = '\u002b';
var MINUS_SIGN = '\u2212';
var GROUPING_SEPARATOR = ' ';
var DECIMAL_SEPARATOR = '.';
var REGULAR_SPACE = ' ';

/**
 * Mirrors `SimplifiedAmountFormatter.space(for:)`: regular space when the token symbol is
 * ASCII-Latin-letters only (e.g. NOT, tsTON, USDT), thin space otherwise (e.g. USD₮).
 */
function jettonSymbolSeparator(symbol) {
    return /^[A-Za-z]+$/.test(String(symbol)) ? REGULAR_SPACE : THIN_SPACE;
}

function nativeTokenDisplayName() {
    if (typeof NATIVE_TOKEN_SHORT_TEXT !== 'undefined' && NATIVE_TOKEN_SHORT_TEXT) {
        return String(NATIVE_TOKEN_SHORT_TEXT);
    }
    throw new Error('formatter.js: NATIVE_TOKEN_SHORT_TEXT is not set');
}

var COMPACT_MAX_FRACTION_DIGITS = 2;
var COMPACT_MAX_SIGNIFICANT_FRACTION_DIGITS = 3;

function digitString(amount) {
    if (amount === undefined || amount === null) return '0';
    if (typeof BigInt !== 'undefined' && typeof amount === 'bigint') {
        return amount < BigInt(0) ? (-amount).toString() : amount.toString();
    }
    var s = String(amount).trim();
    if (/^-?\d+$/.test(s)) return s.charAt(0) === '-' ? s.substring(1) : s;
    if (typeof amount === 'number' && Number.isFinite(amount)) {
        var rounded = Math.round(amount);
        if (Math.abs(amount - rounded) < 1e-9) {
            amount = rounded;
        }
        if (Number.isSafeInteger(amount)) {
            return String(Math.trunc(Math.abs(amount)));
        }
        // Loss of precision above 2^53-1: caller should pass balance as a string from JSON.
        var t = String(amount);
        if (/^-?\d+$/.test(t)) return t.charAt(0) === '-' ? t.substring(1) : t;
    }
    return '0';
}

function splitAmountParts(amount, fractionDigits) {
    var scale = Math.max(0, fractionDigits | 0);
    var amountString = digitString(amount);
    if (scale === 0) {
        return { integer: amountString === '' ? '0' : amountString, fraction: '' };
    }
    var needsPadding = amountString.length <= scale;
    var padded = needsPadding
        ? new Array(scale - amountString.length + 2).join('0') + amountString
        : amountString;
    var splitIndex = padded.length - scale;
    var integerPart = padded.substring(0, splitIndex);
    var fractionPart = padded.substring(splitIndex);
    return {
        integer: integerPart === '' ? '0' : integerPart,
        fraction: fractionPart
    };
}

function isZero(integer, fraction) {
    return integer === '0' && (fraction === '' || /^0+$/.test(fraction));
}

function trimTrailingZerosString(str) {
    var result = str;
    while (result.length > 0 && result.charAt(result.length - 1) === '0') {
        result = result.slice(0, -1);
    }
    return result;
}

function truncatedParts(integer, fraction, maxFractionDigits) {
    var fractionEnd = Math.min(maxFractionDigits, fraction.length);
    var trimmed = trimTrailingZerosString(fraction.substring(0, fractionEnd));
    return { integer: integer, fraction: trimmed === '' ? null : trimmed };
}

function applyCompactLessThanOneRules(fraction) {
    var i;
    for (i = 0; i < fraction.length; i++) {
        if (fraction.charAt(i) !== '0') break;
    }
    if (i >= fraction.length) {
        return { integer: '0', fraction: null, isZero: true };
    }
    var firstSignificantOffset = i;
    var maximumEndOffset = firstSignificantOffset + COMPACT_MAX_SIGNIFICANT_FRACTION_DIGITS;
    var endIndex = Math.min(maximumEndOffset, fraction.length);
    var trimmed = trimTrailingZerosString(fraction.substring(0, endIndex));
    if (trimmed === '') {
        return { integer: '0', fraction: null, isZero: true };
    }
    return { integer: '0', fraction: trimmed, isZero: false };
}

function applyCompactRules(integer, fraction) {
    if (isZero(integer, fraction)) {
        return { integer: '0', fraction: null, isZero: true };
    }
    if (integer === '0') {
        return applyCompactLessThanOneRules(fraction);
    }
    var rp = truncatedParts(integer, fraction, COMPACT_MAX_FRACTION_DIGITS);
    return {
        integer: rp.integer,
        fraction: rp.fraction,
        isZero: false
    };
}

function applyGrouping(integer) {
    if (integer.length <= 3) return integer;
    var parts = [];
    var index = integer.length;
    while (index > 0) {
        var start = Math.max(0, index - 3);
        parts.push(integer.substring(start, index));
        index = start;
    }
    parts.reverse();
    return parts.join(GROUPING_SEPARATOR);
}

/**
 * @param {string} signPolicy 'none' | 'always'
 * @param {boolean} isNegative
 * @param {boolean} isZero
 */
function buildFormattedNumber(parts, signPolicy, isNegative, isZero) {
    var groupedInteger = applyGrouping(parts.integer);
    var numberString;
    if (parts.fraction !== null && parts.fraction !== '') {
        numberString = groupedInteger + DECIMAL_SEPARATOR + parts.fraction;
    } else {
        numberString = groupedInteger;
    }
    if (isZero) {
        return numberString;
    }
    if (signPolicy === 'always') {
        var signChar = isNegative ? MINUS_SIGN : PLUS_SIGN;
        return signChar + THIN_SPACE + numberString;
    }
    return numberString;
}

/**
 * Format integer minor-unit amount with KeeperCore compact rules.
 * @param {*} amount raw balance (string digits preferred)
 * @param {number} fractionDigits
 * @param {object} [opts]
 * @param {string} [opts.symbol] trailing symbol (e.g. USD₮)
 * @param {'none'|'always'} [opts.signPolicy]
 * @param {boolean} [opts.isNegative]
 */
function formatCompactMinorUnits(amount, fractionDigits, opts) {
    opts = opts || {};
    var signPolicy = opts.signPolicy || 'none';
    var isNegative = !!opts.isNegative;
    var parts = splitAmountParts(amount, fractionDigits);
    var compact = applyCompactRules(parts.integer, parts.fraction);
    var isZero = !!compact.isZero;
    var num = buildFormattedNumber(compact, signPolicy, isNegative, isZero);
    if (opts.symbol) {
        return num + THIN_SPACE + opts.symbol;
    }
    return num;
}

/**
 * TonAPI `balance` is nanotons (integer). Compact display matches KeeperCore `AmountFormatter`
 * default `.compact` truncation rules.
 */
function formatTon(amount) {
    return formatCompactMinorUnits(amount, 9, {});
}

function formatJetton(amount, decimals) {
    var d = decimals === undefined || decimals === null ? 9 : Number(decimals);
    return formatCompactMinorUnits(amount, d, {});
}

var USDT_DECIMALS = 6;

function formatUsdt(amount) {
    return formatCompactMinorUnits(amount, USDT_DECIMALS, {});
}

/**
 * Same as `SignedAccountEventAmountMapper` + `AmountFormatter` (`.compact`, `signPolicy` `.always`)
 * for jetton swap "received" line (`AccountEventMapper.mapJettonSwapAction` out / income).
 */
function formatHistoryJettonIncomeLine(amount, fractionDigits, symbol) {
    var sym = symbol || 'USD₮';
    var separator = jettonSymbolSeparator(sym);
    var num = formatCompactMinorUnits(amount, fractionDigits, {
        signPolicy: 'always',
        isNegative: false
    });
    if (num === '0') {
        return '0' + separator + sym;
    }
    return num + separator + sym;
}

/**
 * Signed native token line for history (`SignedAccountEventAmountMapper` + signed `AmountFormatter`, compact).
 * `isNegative` true for stake deposit outcome; false for completed withdraw stake income.
 *
 * Mirrors `AmountFormatter.buildFormattedString`: the sign is `minus/plus + config.space`
 * where `config.space` is the thin space (U+2009) (`FormattersAssembly`), while the symbol
 * separator is `space(for:)` — a regular space for ASCII-Latin symbols (e.g. GRAM), thin
 * otherwise. So "1 GRAM" outcome renders as `−\u20091 GRAM` (thin sign gap, regular symbol gap).
 */
function formatSignedCompactTonWithTokenSuffix(amount, isNegative) {
    var symbol = nativeTokenDisplayName();
    var symbolSeparator = jettonSymbolSeparator(symbol);
    var sign = isNegative ? MINUS_SIGN : PLUS_SIGN;
    var num = formatCompactMinorUnits(amount, 9, { signPolicy: 'none' });
    return sign + THIN_SPACE + num + symbolSeparator + symbol;
}

/**
 * Jetton burn / spend line (`mapJettonBurnAction`): signed compact amount + token symbol.
 */
function formatHistoryJettonOutcomeLine(amount, fractionDigits, symbol) {
    var sym = symbol || 'tsTON';
    var separator = jettonSymbolSeparator(sym);
    var num = formatCompactMinorUnits(amount, fractionDigits, {
        signPolicy: 'always',
        isNegative: true
    });
    if (num === '0') {
        return MINUS_SIGN + THIN_SPACE + '0' + separator + sym;
    }
    return num + separator + sym;
}

function toExactVisiblePattern(text) {
    return String(text)
        .replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
        .replace(/\u2009/g, '\\u2009');
}

output.formatter = {
    formatJetton: formatJetton,
    formatTon: formatTon,
    formatUsdt: formatUsdt,
    formatHistoryJettonIncomeLine: formatHistoryJettonIncomeLine,
    formatSignedCompactTonWithTokenSuffix: formatSignedCompactTonWithTokenSuffix,
    formatHistoryJettonOutcomeLine: formatHistoryJettonOutcomeLine,
    toExactVisiblePattern: toExactVisiblePattern
};

(function maestroFormatterSanityCheck() {
    var ton = output.formatter.formatTon(2265256703);
    if (ton !== '2.26') {
        throw new Error(
            'formatter.js: formatTon(2265256703) expected "2.26" (Swift compact), got "' +
                ton +
                '". Refresh script / engine.'
        );
    }
    var smallTon = output.formatter.formatTon(4029);
    if (smallTon !== '0.00000402') {
        throw new Error(
            'formatter.js: formatTon(4029) expected "0.00000402" (Swift compact), got "' +
                smallTon +
                '". Refresh script / engine.'
        );
    }
})();
