const esbuild = require('esbuild');

const watch = process.argv.includes('--watch');
const prod = process.env.NODE_ENV === 'production';

const options = {
  entryPoints: ['src/extension.ts'],
  bundle: true,
  outfile: 'dist/extension.js',
  external: ['vscode'],
  platform: 'node',
  target: 'node18',
  format: 'cjs',
  sourcemap: !prod,
  minify: prod,
  logLevel: 'info',
};

if (watch) {
  esbuild.context(options).then((ctx) => ctx.watch());
} else {
  esbuild.build(options).catch(() => process.exit(1));
}
