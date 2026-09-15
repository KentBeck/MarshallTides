// Bundles the page into one self-contained HTML file that opens straight
// from disk (browsers won't load ES modules from file://). No dependencies.
//   node build.mjs   ->   dist/marshall-tides.html

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';

const order = ['time', 'astro', 'tides', 'weather', 'sample-data', 'model', 'chart', 'widgets', 'app'];

const modules = order.map(name => {
  let src = readFileSync(`src/${name}.js`, 'utf8');
  const exports = [...src.matchAll(/^export (?:async )?(?:function|const|let|class) (\w+)/gm)].map(m => m[1]);
  src = src
    .replace(/^import \{([^}]*)\} from '\.\/(\w[\w-]*)\.js';/gm, (_, names, mod) => `const {${names}} = __modules['${mod}'];`)
    .replace(/^export /gm, '');
  return `__modules['${name}'] = (() => {\n${src}\nreturn { ${exports.join(', ')} };\n})();`;
});

const script = `const __modules = {};\n${modules.join('\n\n')}`;
const css = readFileSync('style.css', 'utf8');
const html = readFileSync('index.html', 'utf8')
  .replace('<link rel="stylesheet" href="style.css">', `<style>\n${css}</style>`)
  .replace('<script type="module" src="src/app.js"></script>', `<script>\n${script}\n</script>`);

mkdirSync('dist', { recursive: true });
writeFileSync('dist/marshall-tides.html', html);
console.log(`dist/marshall-tides.html  ${(html.length / 1024).toFixed(0)} kB`);
