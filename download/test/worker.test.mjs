import { test } from 'node:test';
import assert from 'node:assert/strict';
import { latestRelease } from '../worker.mjs';
const encoder = new TextEncoder();
const keys = await crypto.subtle.generateKey('Ed25519', true, ['sign', 'verify']);
const publicKey = Buffer.from(await crypto.subtle.exportKey('raw', keys.publicKey)).toString('base64');
function item(version, build, url = `https://updates.msgblast.app/downloads/msgblast-${version}-${build}.zip`) {
  return `<item><sparkle:version>${build}</sparkle:version><sparkle:shortVersionString>${version}</sparkle:shortVersionString><enclosure url="${url}" length="123" /></item>`;
}
async function signed(xml) {
  const bytes = encoder.encode(xml);
  const signature = Buffer.from(await crypto.subtle.sign('Ed25519', keys.privateKey, bytes)).toString('base64');
  return encoder.encode(`${xml}<!-- sparkle-signatures:\nedSignature: ${signature}\nlength: ${bytes.length}\n-->`);
}
test('chooses the highest build, independent of version and item order', async () => {
  const result = await latestRelease(await signed(`<rss>${item('1.0', '9')}${item('0.1.1', '10')}${item('0.1.0', '2')}</rss>`), publicKey);
  assert.deepEqual(result, { version: '0.1.1', build: '10', url: 'https://updates.msgblast.app/downloads/msgblast-0.1.1-10.zip' });
});
test('rejects tampering with a valid signed feed', async () => {
  const bytes = await signed(`<rss>${item('0.1.1', '3')}</rss>`);
  bytes[8] ^= 1;
  await assert.rejects(latestRelease(bytes, publicKey), /signature failed/);
});
test('rejects missing signatures and wrong signing keys', async () => {
  await assert.rejects(latestRelease(encoder.encode('<rss/>'), publicKey), /Missing/);
  await assert.rejects(latestRelease(await signed(`<rss>${item('0.1.1', '3')}</rss>`)), /signature failed/);
});
test('rejects redirect destinations outside the immutable archive convention', async () => {
  for (const url of ['https://evil.example/app.zip', 'https://updates.msgblast.app/downloads/msgblast-0.1.1-3.zip?next=evil', 'https://updates.msgblast.app/downloads/msgblast-0.1.1-4.zip']) {
    await assert.rejects(latestRelease(await signed(`<rss>${item('0.1.1', '3', url)}</rss>`), publicKey), /destination/);
  }
});
test('release notes and comments cannot supply fake items', async () => {
  const fake = item('99.0', '999');
  const result = await latestRelease(await signed(`<rss><!--${fake}--><description><![CDATA[${fake}]]></description>${item('0.1.1', '3')}</rss>`), publicKey);
  assert.equal(result.build, '3');
});
test('rejects malformed or absent release metadata and oversized feeds', async () => {
  for (const xml of ['<rss/>', `<rss>${item('0.1.1', '0')}</rss>`, `<rss>${item('0.1.1', '3').replace('<enclosure', '<missing')}</rss>`]) {
    await assert.rejects(latestRelease(await signed(xml), publicKey));
  }
  await assert.rejects(latestRelease(new Uint8Array(256 * 1024 + 1), publicKey), /size/);
});
test('signed length counts UTF-8 bytes and must end at the signature trailer', async () => {
  const xml = `<rss><description>café 🍏</description>${item('0.1.1', '3')}</rss>`;
  assert.equal((await latestRelease(await signed(xml), publicKey)).build, '3');
  const bytes = await signed(xml);
  await assert.rejects(latestRelease(encoder.encode(new TextDecoder().decode(bytes).replace('<!-- sparkle-signatures:', 'extra<!-- sparkle-signatures:')), publicKey), /trailer/);
});
