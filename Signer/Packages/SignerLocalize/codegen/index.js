const fs = require('fs');
const config = require('./config');

function parseStringsFile(file) {
  console.log(file);
    const content = fs.readFileSync(file, 'utf8');

    const lines = content.split('\n');
    const result = {};

    lines.forEach(line => {
        if(line) {
            const [fullMatch, key, value] = line.match(/"(.+)" = "(.+)"/) || [];
            const tokens = key.split('.');

            let temp = result;
            for(const token of tokens.slice(0, -1)) {
                if(!(token in temp)) {
                    temp[token] = {};
                }
                temp = temp[token];
            }

            temp[tokens[tokens.length - 1]] = value;
        }
    });

    return result;
}

function convertToEnum(keyword) {
    return keyword.split('_').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join('');
}

function generateSwiftCode(parsed, parents = []) {
    let swiftCode = '';

    for(let [key, value] of Object.entries(parsed)) {
        const indent = '  '.repeat(parents.length + 1);

        let fullKey = [...parents, key].join('.');

        if(typeof value === 'object') {
            swiftCode += `${indent}public enum ${convertToEnum(key)} {\n`;
            swiftCode += generateSwiftCode(value,[...parents, key]);
            swiftCode += `${indent}}\n`;
        } else {
            const args = value.match(/%@/g);

            if (!args) {
                swiftCode += `${indent}/// ${value}\n`;
                swiftCode += `${indent}public static var ${key}: String {\n`;
                swiftCode += `${indent}  localize(\"${fullKey}\")\n`;
                swiftCode += `${indent}}\n`;
            } else {
                const params = args.map((_, idx) => `_ p${idx}: Any`).join(', ');
                const callParams = args.map((_, idx) => `String(describing: p${idx})`).join(', ');

                swiftCode += `${indent}/// ${value}\n`;
                swiftCode += `${indent}public static func ${key}(${params}) -> String {\n`;
                swiftCode += `${indent}  return localizeWithArgs(\"${fullKey}\", ${callParams})\n`;
                swiftCode += `${indent}}\n`;
            }
        }
    }

    return swiftCode;
}

function generateLocaleEnum(stringsFilePath, enumFilePath) {
    const parsedData = parseStringsFile(stringsFilePath);

    let swiftCode = 'public enum SignerLocalize {\n';
    swiftCode += generateSwiftCode(parsedData);
    swiftCode += '}';

    fs.writeFileSync(enumFilePath, swiftCode);
}

generateLocaleEnum(config.stringsFilePath, config.codePath);
