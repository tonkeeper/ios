// this script is intended to be runed with bun.sh
// it will generate a json file with all the translations using chatgpt
//
// Usage:
//  bun translate.js indonesian
//
//  third param is an language you are translating to
//
import {readdir, readFile} from 'node:fs/promises';

const config = require('./config');

const SNAPSHOTS_DIR = './__snapshots__/';

const translateTo = Bun.argv[2];
let translated = 0;
let total = 0;

async function query(prompt, message) {
    const resp = await fetch('https://api.datafield.io/gpt/prompt', {
        method: 'POST',
        body: JSON.stringify({
            prompt: prompt,
            message: message,
        }),
        headers: { 'Content-Type': 'application/json' },
    });
    let jsonResponse = await resp.json();
    return jsonResponse['json'];
}

function appendResult(result, value, lang) {
    if (!result) result = {};
    if (typeof value === 'string') {
        result[lang] = value;
    }
    if (typeof value === 'object') {
        for (let k in value) {
            result[k] = appendResult(result[k], value[k], lang);
        }
    }
    return result;
}

function setNestedValue(obj, keys, value) {
    let current = obj;
    keys.forEach((key, index) => {
        if (!current[key]) {
            current[key] = {};
        }

        if (index === keys.length - 1) {
            current[key] = value;
        }

        current = current[key];
    });
}

function parseLocalizeable(file) {
    const lines = file.split('\n');
    const obj = {};

    lines.forEach(line => {
        const cleanedLine = line.replace(/\/\*.*\*\//, '').trim();

        if (cleanedLine) {
            const match = cleanedLine.match(/"([^"]+)"\s*=\s*"([^"]+)";/);

            if (match && match.length === 3) {
                const key = match[1];
                const value = match[2];
                setNestedValue(obj, key.split('.'), value);
            }
        }
    });

    return obj;
}

async function scanDirectory(setup) {
    let result = {};
    // Read the current directory
    const files = await readdir(config.localesPath);

    // Filter for lproj files
    let promises = files
        .filter((file) => file.endsWith('.lproj'))
        .map(async (file) => {
            let lang = file.split('.')[0];
            let langFile = Bun.file(`${config.localesPath}/${file}/Localizable.strings`);
            let localizeableText = await langFile.text();
            let json = parseLocalizeable(localizeableText);

            for (let k in json) {
                result[k] = appendResult(result[k], json[k], lang);
            }
        });
    await Promise.all(promises);
    // read snapshot
    try {
        let langFile = Bun.file(SNAPSHOTS_DIR + setup.code + '.json');
        let json = await langFile.json();

        console.log('Snapshot found');

        for (let k in json) {
            result[k] = appendResult(result[k], json[k], 'snapshot');
        }
    } catch {
        console.log('Snapshot not found');
    }
    return result;
}

async function findOutSetup(langIdentifyer) {
    let prompt = `You will get an message with an language identifier, either in form of language name, or short code of it,
I will ask you to response with an valid JSON of following structure:
just json object with fields: code - short code of language, name - name of language, nativeName - native name of language, rtl - boolean if language is right to left.
example:
{"code": "en", "name": "English", "nativeName": "English", "rtl": false}. You must response with ONLY json object, nothing else`;
    const res = await query(prompt, langIdentifyer);
    return JSON.parse(res);
}

function countKeysRecursive(obj, langCode) {
    for (let k in obj) {
        if (typeof obj[k] === 'string') {
            // we found a lang key
            if (obj[langCode]) {
                translated++;
            }
            total++;
            return;
        }
        if (typeof obj[k] === 'object') {
            countKeysRecursive(obj[k], langCode);
        }
    }
}

function clearTranslation(obj, langCode) {
    let cleared = {};
    for (let k in obj) {
        if (typeof obj[k] === 'string') {
            // we found a lang key
            return obj[langCode]; // replace it with final lang code
        }
        if (typeof obj[k] === 'object') {
            let value = clearTranslation(obj[k], langCode);
            if (value && JSON.stringify(value) !== '{}') {
                cleared[k] = value;
            }
        }
    }
    return cleared;
}

function convertObjectToLocalizableStrings(obj, prefix = '') {
    let result = '';

    for (const key in obj) {
        if (obj.hasOwnProperty(key)) {
            const value = obj[key];
            const newKey = prefix ? `${prefix}.${key}` : key;

            if (typeof value === 'object') {
                // Recursively handle nested objects
                result += convertObjectToLocalizableStrings(value, newKey);
            } else {
                // Add key-value pair to the result string
                result += `"${newKey}" = "${value}";\n`;
            }
        }
    }
    return result;
}

async function doTranslate(obj, setup, keyChain) {
    let key = keyChain.join('.');
    let prompt = `You are an translator bot. You are helping to translate JSON lang file for an javascript application to a ${setup.name} language. You will get an message with an json object of following structure – each key is a lang identifier (example: "en"), and value is the translation in that language. Using this info please translate same phrase to ${setup.name} language and return only translation string without quotes.
Never reply with anything except translation. Never ask for help or anything else, make sure to return only translation.
If you see any unordinary symbols like quotes or anything else – try to preserve the same symbols in the translation.
You all languages from json you get for translation to generate most suitable language key in return. Do not add any new symbols like "\\n", which wasn't presented in original string.
Try to generate translation not much longer or much shorter than it is in other languages.
If language available in latin and cyrillic then the most popular one.
Some hint for the translation – you are translating an language key stored in ${key} field.`;

    let description = obj['description'];
    let langs = Object.assign({}, obj);
    delete langs['description'];

    if (description) {
        prompt += `\nIts also an additional description provided for this field, wich may help you with translation: ${description}`;
        console.log('DESC:', description);
    }

    let response = await query(prompt, JSON.stringify(langs));
    response = response.replace(/^"|"$/gm, '');
    console.log(
        `\nTanslating \x1B[31m${translated} \x1b[37mfrom \x1B[31m${total}\x1b[37m:`,
    );
    let p = `\x1B[34m${key}\x1b[37m\n`;
    if (obj['en']) {
        p += `en: ` + obj['en'];
    } else if (obj['ru-RU']) {
        p += `ru: ` + obj['ru-RU'];
    }
    p += '\n\x1B[32m' + setup.code + ': ' + response + '\x1b[37m';
    console.log(p);
    translated++;
    return response;
}

async function translate(obj, setup, cb, keyChain) {
    for (let k in obj) {
        if (typeof obj[k] === 'string') {
            const hasChanges = obj['en'] !== obj['snapshot'];
            // we found a lang key
            if (obj[setup.code] && !hasChanges) {
                return obj; // skip translation for that one
            }
            obj[setup.code] = await doTranslate(obj, setup, keyChain);
            await cb(); // write file here
            return obj;
        }
        if (typeof obj[k] === 'object') {
            obj[k] = await translate(obj[k], setup, cb, [...keyChain, k]);
        }
    }
    return obj;
}

async function main() {
    console.log(
        'Hello, we are about to generate lang files, but first we going to read all the translation files and build an translations map.',
    );

    let setup = await findOutSetup(translateTo);

    let langs = await scanDirectory(setup);

    let fileName = `${config.localesPath}/${setup.code}.lproj/Localizable.strings`;
    console.log(
        'We are going to create new translation for',
        translateTo,
        'language and write it to',
        fileName,
    );

    const output = Bun.file(fileName);
    if (output.size !== 0) {
        console.log('File already exists, so we going to update it.');
    }

    console.log('setup', setup);
    countKeysRecursive(langs, setup.code);
    await translate(
        langs,
        setup,
        async () => {
            let translatedLang = clearTranslation(langs, setup.code);
            await Bun.write(fileName, convertObjectToLocalizableStrings(translatedLang, null, 2));
        },
        [],
    );
    // update snapshot
    await Bun.write(SNAPSHOTS_DIR + setup.code + '.json', JSON.stringify(langs));
    console.log('Snapshot for ' + setup.code + ' updated');
}
main();
