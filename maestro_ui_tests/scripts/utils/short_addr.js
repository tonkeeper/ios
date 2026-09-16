// Matches String.shortenedMiddle. Confirmation uses 6+6; history cells use 4+4
// (FriendlyAddress.toShort / MultichainAddressFormatter.shortAddress).
var rawPrefix = typeof prefixLength === "undefined" ? "" : prefixLength;
var rawSuffix = typeof suffixLength === "undefined" ? "" : suffixLength;
var prefixLen = parseInt(rawPrefix, 10);
var suffixLen = parseInt(rawSuffix, 10);
if (isNaN(prefixLen)) prefixLen = 6;
if (isNaN(suffixLen)) suffixLen = 6;

var hexPrefix = addr.toLowerCase().indexOf("0x") === 0 ? addr.substring(0, 2) : "";
var body = addr.substring(hexPrefix.length);
if (body.length <= prefixLen + suffixLen) {
    output.shortAddrRecieve = addr;
} else {
    output.shortAddrRecieve = hexPrefix + body.substring(0, prefixLen) + "..." + body.substring(body.length - suffixLen);
}
