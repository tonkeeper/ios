const words = phrase.trim().split(/\s+/);

// TON-only phrases have 24 words, multichain (BIP39) ones 12.
if (words.length !== 24 && words.length !== 12) {
  throw new Error(`Expected 12 or 24 words, but got ${words.length}. Check your phrase.`);
}

output.word = words;
