var text = (output.captionText || "").trim();
var match = text.match(/\d+/g);

output.indices = [];
if (match) {
  for (var i = 0; i < match.length; i++) {
    output.indices.push(parseInt(match[i], 10));
  }
}
