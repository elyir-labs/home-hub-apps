// Draws the app icon from the hub's own (app/public/icon.svg in the hub's repository): the same house, full bleed,
// because iOS rounds the corners itself, and opaque, because the App Store refuses an icon with transparency.
// `node tools/icon.mjs <hub checkout>`; it uses the hub's Playwright (cd app && npm ci there).
import { readFileSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import path from 'node:path'

const hub = path.resolve(process.argv[2] ?? '../home-hub')
const { chromium } = await import(path.join(hub, 'app/node_modules/playwright/index.mjs'))
const svg = readFileSync(path.join(hub, 'app/public/icon.svg'), 'utf8').replaceAll(' rx="112"', '')
const out = new URL('../ios/Houses/Assets.xcassets/AppIcon.appiconset/icon-1024.png', import.meta.url).pathname

const browser = await chromium.launch()
const page = await browser.newPage({ viewport: { width: 1024, height: 1024 } })
await page.setContent(`<body style="margin:0;background:#0c0d10">${svg.replace('<svg ', '<svg width="1024" height="1024" ')}</body>`)
await page.screenshot({ path: out, omitBackground: false })
await browser.close()
// Through JPEG and back drops the alpha channel the screenshot carries even when every pixel is opaque.
execFileSync('sips', ['-s', 'format', 'jpeg', '-s', 'formatOptions', '100', out, '--out', out + '.jpg'])
execFileSync('sips', ['-s', 'format', 'png', out + '.jpg', '--out', out])
execFileSync('rm', [out + '.jpg'])
console.log('drew', path.relative(process.cwd(), out))
